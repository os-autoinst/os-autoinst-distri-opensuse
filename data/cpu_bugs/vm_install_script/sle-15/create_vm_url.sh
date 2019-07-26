#!/bin/sh -e

if [ $# -lt 5 ]; then
    echo "$0 <name> <install_url> <autoyast_url> <logfile_path> <vm_pool> [cpu]"
    exit 1
fi

NAME="${1:?"name parameter is required"}"
INSTALL_URL="${2:?"Install URL is required"}"
AUTOYAST_URL="${3:?"autoyast file's URL is required"}"
LOGFILE="${4:?"logfile path is required"}"
QCOW2POOL="${5:?"QCOW2POOL path is required"}"
CPU="${6:-"host-model-only"}"

mkdir -pv "${QCOW2POOL}"

virt-install --name "${NAME}" \
    --disk path="${QCOW2POOL}\/${NAME}.qcow2",size=20,format=qcow2,bus=virtio,cache=none \
    --os-variant sle15 \
    --noautoconsole \
    --wait=-1 \
    --vnc \
    --vcpus=4 \
    --cpu "${CPU}"\
    --ram=1024 \
    --console=log.file="${LOGFILE}"\
    --network bridge=br0,model=virtio \
    --location="${INSTALL_URL}" \
    -x "console=ttyS0,115200n8
        install=${INSTALL_URL}
	autoyast=${AUTOYAST_URL}"


