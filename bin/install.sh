#!/usr/bin/env bash

SCRIPT="${0}"






















mnt="tmp"; rootFS="$mnt/root.x86_64";
packages_I=('dosfstools' 'ntfs-3g' 'parted' 'gdisk')
packages_II=('base' 'base-devel' 'linux' 'linux-headers' 'linux-firmware' 'networkmanager' 'network-manager-applet'
         'plasma' 'plasma-wayland-session' 'grub' 'sddm' 'xorg' 'xorg-server' 'xorg-xinit' 'efibootmgr'
         'dosfstools' 'mtools' 'os-prober' 'wget' 'curl' 'git' 'axel' 'lftp' 'aria2' 'vlc' 'dolphin' 'konsole' 
         'kitty' 'bash-completion' 'zsh' 'cmake' 'extra-cmake-modules' 'sof-firmware' 'intel-ucode' 
         'xf86-video-intel' 'vulkan-intel' 'intel-media-driver' 'mesa' 'alsa-utils' 'alsa-plugins' 'alsa-firmware' 
         'pulseaudio' 'ffmpeg' 'chromium' 'gparted' 'okular' 'micro' 'nano')

tarBall='blacknet-bootstrap-x86_64.tar.gz'
globalMirror="https://geo.mirror.pkgbuild.com"


GREEN='\033[32m'
CYAN='\033[36m'
RESET='\033[0m'

start_spinner () {
    set +m
    echo -ne "$(INFO "$1")              "
    { while : ; do for X in '  •     ' '   •    ' '    •   ' '     •  ' '      • ' '     •  ' '    •   ' '   •    ' '  •     ' ' •      ' ; do echo -en "\b\b\b\b\b\b\b\b$X" ; sleep 0.1 ; done ; done & } 2>/dev/null
    spinner_pid=$!
}

stop_spinner () {
    { kill -9 $spinner_pid && wait; } 2>/dev/null
    set -m
    echo -en "\033[2K\r"
}

_date_time () { date +"%Y/%m/%d %H:%M:%S"; }

_utc_date_time () { date -u +"%Y/%m/%dT%H:%M:%SZ"; }

_log () {
    local date_time msg level
    msg="${1}"
    level="${2:-${FUNCNAME[1]}}"
    date_time=$(_date_time)

    echo -e "${CYAN}[$date_time][$level]${RESET}${GREEN} $msg${RESET}"
}



INFO () { _log "${1}"; }

grub-setup () {
    INFO "Install Grub Bootloader"; grub-install --bootloader-id="$1" &>/dev/null
    INFO "Enable OS-Prober"; sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
    mkdir -p /var/lock/dmraid &>/dev/null
    INFO "Create Grub Configuration"; grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null    
}

create_user () {
    INFO "Create User"; useradd -m "$1" &>/dev/null
    INFO "Set User Group"; usermod -aG wheel "$1" &>/dev/null

}

set_passwords () {
    # $1 => Username
    # $2 => User Password
    # $3 => Root Password
    
    INFO "Create User Password"; echo -ne "$2\n$2" | passwd "$1" &>/dev/null
    INFO "Create Root Password"; echo -ne "$3\n$3" | passwd &>/dev/null
}

configure () {
    INFO "Unpacking Bootstrap"; tar -xzf "src/$tarBall" -C "tmp" --numeric-owner &>/dev/null
    INFO "Create Termninfo"; [[ -d '/usr/share/terminfo' ]] && cp -r '/usr/share/terminfo' "$rootFS/usr/share/"
    cp "$SCRIPT" "$rootFS/";
    INFO "Create Mirrorlist"; printf 'Server = %s/$repo/os/$arch\n' "$globalMirror" >> "$rootFS/etc/pacman.d/mirrorlist" 
    mount --bind "$rootFS" "$rootFS"; "$rootFS/bin/arch-chroot" "$rootFS" /usr/bin/bash install.sh -2
}

setup () {

    SCRIPTII="${SCRIPT##*/}"

    
    INFO "Setup Systemd Machine ID"; systemd-machine-id-setup &>/dev/null

    start_spinner "Pacman-Key Initialization" 
        pacman-key --init &>/dev/null
    stop_spinner

    start_spinner "Pacman-Key Populate"
        pacman-key --populate &>/dev/null
    stop_spinner

    start_spinner "Update Package Database"
        pacman -Syu --needed --noconfirm "${packages_I[@]}" &>/dev/null
    stop_spinner
    
    INFO "Wiping Root Partition"; wipefs -a -f "$ROOT" &>/dev/null
    INFO "Format Root Partition"; mkfs.ext4 "$ROOT" &>/dev/null
    INFO "Wiping EFI Partition"; wipefs -a -f "$EFI" &>/dev/null
    INFO "Formating EFI Partition"; mkfs.fat -F 32 "$BOOT" &>/dev/null

    function GREP_DISK () {
        lsblk | grep "$1"
    }


    SDA="$(GREP_DISK "sda")"
    NVME="$(GREP_DISK "nvme")"

    if [ -n "$SDA" ]; then
        disk="sda" &>/dev/null
    elif [ -n "$NVME" ]; then
        disk="nvme0n1" &>/dev/null
    fi

    EFI_PART_NR="${EFI: -1}"

    INFO "Set Boot on"; parted --script "$disk" \
    set "$EFI_PART_NR" boot on &>/dev/null
    
    if [ -n "$CTRL_SWAP" ]; then
        INFO "Wiping Swap Partition"; wipefs -a -f "$SWAP" &>/dev/null
        INFO "Formating Swap Partition"; mkswap "$SWAP" &>/dev/null
        INFO "Set Swap on"; swapon "$SWAP" &>/dev/null
    fi

    INFO "Mount Root Partition"; mount "$ROOT" /mnt &>/dev/null
    
    start_spinner "Install New Environment"
        pacstrap -K /mnt "${packages_II[@]}" &>/dev/null;
    stop_spinner

    INFO "Generate FStab"; genfstab -U -p /mnt >> /mnt/etc/fstab
    cp "${SCRIPTII}" "/mnt/$SCRIPTII" &>/dev/null
    arch-chroot /mnt /usr/bin/bash "$SCRIPTII" -3
    
}

installation () {

    if [ ! -d /boot/efi ]; then
        INFO "Create Boot Directory"; mkdir -p /boot/efi &>/dev/null
    fi
    mount "$EFI" /boot/efi &>/dev/null

    grub-setup "Blacknet"

    create_user "$USERNAME"
    set_passwords "$USERNAME" "$UPASSWD" "$RPASSWD"

    mkdir -p .tmp

    INFO "Download Plasmoids"; wget https://github.com/SL33PZ/cfgs/raw/main/_plasmoids.run -O .tmp/_plasmoids.run &>/dev/null && chmod +x .tmp/_plasmoids.run
    INFO "Download Settings"; wget https://github.com/SL33PZ/cfgs/raw/main/_settings.run -O .tmp/_settings.run &>/dev/null && chmod +x .tmp/_settings.run
    
    INFO "Install Plasmoids"; ./.tmp/_plasmoids.run &>/dev/null
    INFO "Install Settings"; ./.tmp/_settings.run &>/dev/null
    rm -rf .tmp
    
    INFO "Setting Language"; echo "LANG=$LANGUAGE" >> /etc/locale.conf
    INFO "Create Locale Configuration"; sed -i "s/#$LANGUAGE/$LANGUAGE/g" /etc/locale.gen && locale-gen &>/dev/null

    INFO "Enable Services"; systemctl enable \
    NetworkManager.service  \
    sddm.service &>/dev/null
    

}


case $1 in
    -1) configure;;
    -2) setup;;
    -3) installation;;
    *) :;;
esac
