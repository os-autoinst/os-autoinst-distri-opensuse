#!/bin/sh -e
if [ $# -lt 1 ]; then
    echo "$0 <name>"
    exit 1
fi
NAME="${1:?"Need a name to remove VM via virsh."}"
virsh undefine "${NAME}"
virsh destroy "${NAME}"
