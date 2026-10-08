#!/bin/bash -x
#vgpu test guest debugging
date
echo ""
lspci
echo ""
lsmod | grep -i -e nvidia -e kvm
echo ""
nvidia-smi
echo ""
journalctl --cursor-file /tmp/cursor.txt | grep -i -e 'kernel:' -e nvidia
