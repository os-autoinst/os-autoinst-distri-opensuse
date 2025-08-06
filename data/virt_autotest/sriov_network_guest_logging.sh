#!/bin/bash -x
#SR-IOV Ethernet PCI passthrough test guest debugging
echo ""
date
#save udev rules
echo ""
ls -l /etc/udev/rules.d/70-persistent-net.rules
cat /etc/udev/rules.d/70-persistent-net.rules
echo ""
#list pci devices
lspci
echo ""
ip a
echo ""
nmcli con
echo ""
ls -l /etc/sysconfig/network/
echo ""
if [ -d /etc/sysconfig/network/ ]; then
   for FILE in /etc/sysconfig/network/ifcfg-*; do echo $FILE; cat $FILE; done
fi
echo ""
ls -l /etc/NetworkManager/system-connections/
echo ""
if [ -d /etc/NetworkManager/system-connections/ ]; then
  for FILE in /etc/NetworkManager/system-connections/*; do echo "$FILE"; cat "$FILE"; done
fi
echo ""
lsmod | grep -e vf -e virt -e kvm -e xen -e pci
echo ""
journalctl --cursor-file /tmp/cursor.txt | grep -e 'kernel:' -e NetworkManager -e wickedd-dhcp4 -e systemd-udevd
