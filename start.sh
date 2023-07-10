#!/usr/bin/env bash


npm start && wait; 

umount -l "$PWD/tmp/root.x86_64" &>/dev/null && wait && rm -rf "$PWD/tmp/root.86_64" &>/dev/null;


