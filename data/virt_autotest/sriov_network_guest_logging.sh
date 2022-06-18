#!/bin/bash
#xen irqbalance guest debugging
date
set -x
#save udev rules
ls -l /etc/udev/rules.d/70-persistent-net.rules
cat /etc/udev/rules.d/70-persistent-net.rules
echo ""
#list pci devices
lspci
echo ""
ip a
lsmod
