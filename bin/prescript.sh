#!/usr/bin/env bash

RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'



language () {
while true; do
    clear; echo -e "Language:${CYAN}[1]${RESET}German ${CYAN}[2]${RESET}English ${CYAN}[3]${RESET}France ${CYAN}[4]${RESET}Spanish ${CYAN}[5]${RESET}Italian${RESET}"
    read -rp ">>> " LANG

    case $LANG in
        1) sed -i "${1}i export LANGUAGE='de_DE.UTF-8'" bin/install.sh; break;;
        2) sed -i "${1}i export LANGUAGE='en_EN.UTF-8'" bin/install.sh; break;;
        3) sed -i "${1}i export LANGUAGE='fr_FR.UTF-8'" bin/install.sh; break;;
        4) sed -i "${1}i export LANGUAGE='es_ES.UTF-8'" bin/install.sh; break;;
        5) sed -i "${1}i export LANGUAGE='it_IT.UTF-8'" bin/install.sh; break;;
        *) echo -e "${RED}Wrong input!${RESET}"
    esac

    

done
}

input () {
    # $1 => Option
    # $2 => Question
    # $3 => Variable
    OPT=$1

    case $OPT in
        -u)
            while true; do
                clear; read -rp "Username: " VAR
                echo -ne "Correct? ${CYAN}${VAR}${RESET} [y/N]: " 
                read -r ANS

                ANS=${ANS,,}
                VAR=${VAR,,}
                case $ANS in
                    y|ye|yes) 
                    sed -i "${3}i export $2='$VAR'" bin/install.sh; break;;
                    *) shift;;
                esac
            done;;
        -h)
            while true; do
                clear; read -rp "Hostname: " VAR
                echo -ne "Correct? ${CYAN}${VAR}${RESET} [y/N]: " 
                read -r ANS

                ANS=${ANS,,}

                case $ANS in
                    y|ye|yes)
                    sed -i "${3}i export $2='$VAR'" bin/install.sh; break;;
                    *) shift;;
                esac
            done;;
    esac
}

password () {
    while true; do
    #$1 => Question Text: String 
    #$2 => Export Variable Name
    #$3 => Line Number
    clear
    unset PWORD
    PWORD=
    echo -ne "\n$1: " 1>&2
    while true; do
        IFS= read -r -N1 -s char

        code=$(printf '%02x' "'$char")
  
        case "$code" in
            ''|0a|0d) break ;;
            08|7f)
                if [ -n "$PWORD" ]; then
                    PWORD="$( echo "$PWORD" | sed 's/.$//' )"
                    echo -n $'\b \b' 1>&2
                fi;;
    	    15) 
                echo -n "$PWORD" | sed 's/./\cH \cH/g' >&2
                PWORD='';;
            [01]?) ;;
            *)  
                PWORD="$PWORD$char"
                echo -n '*' 1>&2;;
        esac
    done
    unset PWORD2
    PWORD2=
    echo -ne "\nRetype Password: " 1>&2
    while true; do
        IFS= read -r -N1 -s char

        code=$(printf '%02x' "'$char")
  
        case "$code" in
            ''|0a|0d) break ;;
            08|7f)
                if [ -n "$PWORD2" ]; then
                    PWORD="$( echo "$PWORD2" | sed 's/.$//' )"
                    echo -n $'\b \b' 1>&2
                fi;;
    	    15) 
                echo -n "$PWORD2" | sed 's/./\cH \cH/g' >&2
                PWORD2='';;
            [01]?) ;;
            *)  
                PWORD2="$PWORD2$char"
                echo -n '*' 1>&2;;
        esac
    done

    if [ "$PWORD" == "$PWORD2" ]; then
        break;
    else
        echo -ne "${RED}\nPasswords do not match!${RESET}"
        sleep 2
    fi
    done

    sed -i "${3}i export $2='$PWORD'" bin/install.sh
}

partition () {
while true; do
    clear; lsblk -E NAME;
    read -rp "$2 Partition: /dev/" VAR

    echo -ne "Correct? ${CYAN}/dev/${VAR}${RESET} [y/N]: " 
    read -r ANS

    ANS=${ANS,,}

    case $ANS in
        y|ye|yes) sed -i "${3}i export $1='/dev/$VAR'" bin/install.sh; break;;
        *) shift;;
    esac
done
}

SCRIPT(){

    language 7
    input -h HOSTNAME 8
    input -u USERNAME 9

    password "User Password" UPASSWD 10
    password "Root Password" RPASSWD 11

    partition EFI EFI 12
    partition ROOT Root 13

    read -rp "Do you want Swap? [y/N]: " ANS
    ANS=${ANS,,}

    case $ANS in
        y|ye|yes) partition SWAP;;
        *) :;;
    esac
}

sed -i '7,13d' bin/install.sh

SCRIPT

