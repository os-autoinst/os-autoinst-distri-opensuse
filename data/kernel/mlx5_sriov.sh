#!/bin/bash -ex

inc_guid(){
        echo 16o$((0x$1 + 1))p | dc
}
format_guid(){
        echo $1 | sed -e 's/\([0-9A-F][0-9A-F]\)/\1:/g' -e 's/:$//'
}
list_pci_vfs(){
        lspci -D | grep Mellano | grep Virtual | awk '{ print $1}'
}
N_VFS=4

echo $N_VFS > /sys/class/infiniband/mlx5_0/device/sriov_numvfs
echo $N_VFS > /sys/class/infiniband/mlx5_1/device/sriov_numvfs

# Basic IPoIB
ip addr del 192.168.20.1/24 dev ib0 || true
ip addr add 192.168.20.1/24 dev ib0

#Make sure everything is bound first
for pci_id in $(list_pci_vfs); do
        echo $pci_id > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true
done

BASE_GUID=$((ibstat mlx5_0; ibstat mlx5_1 ) | grep "Node GUID:" | awk '{ print $NF}' | sort  | tail -1 | sed -e s/0x//)
GUID=$(inc_guid $BASE_GUID)
for ibIf in ib0 ib1; do
        for i in $(seq 0 $(expr $N_VFS - 1)); do
                CLEAN_GUID=$(format_guid $GUID)
                GUID=$(inc_guid $GUID)
                ip link set $ibIf vf $i state auto
                ip link set $ibIf vf $i port_guid $CLEAN_GUID
                ip link set $ibIf vf $i node_guid $CLEAN_GUID
        done
        ip link set $ibIf up
done
for pci_id in $(list_pci_vfs); do
        echo $pci_id > /sys/bus/pci/drivers/mlx5_core/unbind
        echo $pci_id > /sys/bus/pci/drivers/mlx5_core/bind
done