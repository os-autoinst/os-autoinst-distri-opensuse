#!/bin/bash

if [ -z "$1" ]; then
    echo "You should supply the ISO file!"
    echo "  USAGE: ${0} <ISO_FILE> <BIOS/UEFI>"
    exit
fi

# if [$2 -ne "BIOS"]||[$2 -ne "UEFI"]; then
#     echo "You should declare UEFI or BIOS!"
#     echo "  USAGE: ${0} <ISO_FILE> <BIOS/UEFI>"
#     exit
# fi

basename=$(echo "$1" | cut -d '.' -f 1)
echo "***** Creating ${basename}_${2}_unattend.iso from ${1} *****"

mkdir -v "$basename" "${basename}_${2}_unattend"
sudo mount -vo loop "$1" "$basename"
rsync -ar "$basename"/ "${basename}_${2}_unattend/"
chmod -R 755 "${basename}_${2}_unattend"
cd "${basename}_${2}_unattend" || exit; pwd
cp -v "../Autounattend_${2}.xml" "Autounattend.xml"
mkisofs -quiet -iso-level 4 -udf -R -D -U -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-load-seg 1984 -eltorito-alt-boot -b efi/microsoft/boot/efisys.bin -no-emul-boot -o "${basename}_${2}_unattend.iso" .
chmod 755 "${basename}_${2}_unattend.iso"
cp -v ./*.iso ..
cd ..; pwd
sudo umount -v "$basename"
rm -rf "$basename" "${basename}_${2}_unattend"
