#!/bin/bash

GRUB_PASSWD=$1

grub2-mkpasswd-pbkdf2 <<EOF
$GRUB_PASSWD
$GRUB_PASSWD
EOF
