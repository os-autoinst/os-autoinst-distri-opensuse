#!/bin/bash -x
#xen irqbalance guest debugging
date
#save udev rules
ls -l /etc/udev/rules.d/70-persistent-net.rules
cat /etc/udev/rules.d/70-persistent-net.rules
echo ""
#list pci devices
lspci
echo ""
ip a
echo ""
lsmod | grep -e vf -e virt -e kvm -e xen -e pci
echo ""
journalctl -n 3000 | grep -e 'kernel:' -e wickedd-dhcp4 -e systemd-udevd
