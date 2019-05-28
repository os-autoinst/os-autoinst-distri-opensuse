#!/bin/sh -e


if [ $# -lt 4 ]; then
	echo "[Error]: too few arguments" >&2
	echo "[Notice]: You should make sure the <VM_NAME>-<SUBNAME>.qcow2 at <VM_POOL>" >&2
	echo "Usage:"
	echo "$0 <VM_NAME> <SUBNAME> <VM_POOL> <CPU_FEATRURE>" >&2
	exit 1;
fi

VM_NAME="${1:?"name of VM is requird"}"
SUBNAME="${2:?"subname of VM is requird"}"
VM_POOL="${3:?"name of vm_pooll is requird"}"
CPU="${4:?"CPU Flag pass to virt-install"}"
vm_serial_log=/tmp/"${VM_NAME}-${SUBNAME}"-import.log


virt-install --name "${VM_NAME}-${SUBNAME}" \
	--disk path="${VM_POOL}\/${VM_NAME}-${SUBNAME}".qcow2,format=qcow2,bus=virtio,cache=none,boot_order=1 \
	--import \
	--noautoconsole \
	--vcpus=4 \
	--cpu "${CPU}" \
	--ram=1024 \
	--console=log.file="${vm_serial_log}" \
	--network bridge=br0,model=virtio \

echo "Listening Log file of VM's serial waitting for VM Boot up.."
sleep 1

(tail -f -n0 "${vm_serial_log}"&) | grep -q "Welcome to SUSE"

virsh destroy "${VM_NAME}-${SUBNAME}"

