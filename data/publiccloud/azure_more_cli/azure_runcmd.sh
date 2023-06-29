#!/bin/bash -u
set -o pipefail
# This bash source is for reporting
# shellcheck disable=1091
. "$(dirname "${BASH_SOURCE[0]}")"/azure_lib_fn.sh
#######################################################################
# File: azure_runcmd.sh
# Command: azure_runcmd.sh <resource groupname> <location> ..........
# Description: Tests Azure Manage run-command cli's on virtual machine.
#              Also list, show , delete the created resource using cli.
# Arguments:
#    Resource Group name
#    Location
#    VM name
#    SSH key
#    Image name
#    Subscription account
#    Admin user
# All arguments are required and the postion specified
# Assumption: script is only invoked from wrapper script azure_vm_cli.pm
##########################################################################

# Required AZ setting variable block with default values
grpname="${1:-oqaclitest}"
location="${2:-westus}"
vmname="${3:-oqacliruncmdvm}"
# This standard variable is not used in this script
# shellcheck disable=2034
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"
account="${6:-a5e130f6-1ae8-48f5-8ca3-322fa4d9800f}"
admin="${7:-azureuser}"

# local variable block
# runcmd: holds name for createing runcommand
# later used for invoking, listing, show, delete
runcmd="oqaclirc"

echo "**Start of AZURE CLI run-command test"
echo "*************************************"

# Resource creation
cmd_status "az_account_set" az account set -s "${account}"
echo "Azure account set to ${account}"


echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "${grpname}" -l "${location}" -o table
echo "Created group ${grpname}"

# start vm provision
echo "Creating vm ${vmname} { az vm create }"
cmd_status "az_vm_create" az vm create \
    --name "${vmname}" \
    --resource-group "${grpname}" \
    --location "${location}" \
    --public-ip-sku Standard \
    --image "${vmximagename}" \
    --generate-ssh-keys \
    --admin-username "${admin}" \
    --enable-agent true \
    --size Standard_D2s_v3
echo "${vmname} vm created"

echo "Invoke run-command to display waagent.conf { az vm run-command invoke }"
cmd_status "az_vm_run-command_invoke" az vm run-command invoke \
    --command-id RunShellScript \
    --resource-group "${grpname}" \
    --name "${vmname}" \
    --scripts "cat /etc/waagent.conf"


echo "Create Run-command ${runcmd} { az vm run-command create } "
cmd_status "az_vm_run-command_create" az vm run-command create --name "${runcmd}" -g "${grpname}" --vm-name "${vmname}" --script "echo Agent-status-ready"

echo "List created Run-command ${runcmd} { az vm run-command list } "
echo "*************************************************************"
cmdlist=$(az vm run-command list --vm-name "${vmname}" -g "${grpname}" --location "${location}" --query "[].{name:name}" -o tsv | head -n 1)
cmd_status "az_vm_run-command_show" az vm run-command show -o table --vm-name "${vmname}" -g "${grpname}" --run-command-name "${cmdlist}" --location "${location}"

echo "Delete Run-command ${runcmd} { az vm run-command delete } "
echo "*************************************************************"
cmd_status "az_vm_run-command_delete" az vm run-command delete -g "${grpname}" --run-command-name "${runcmd}" --vm-name "${vmname}" --yes -y

echo "Delete vm and the associated resources like { az resource list } "
echo "*************************************************************"
cmd_status "az_resource_list" az resource list -o table -g "${grpname}"
az resource list -o table -g "${grpname}" --query "[?contains(name, 'oqacliruncmdvm')].{Name:name,Type:type}" -o tsv

#Get required ids to delete the resource
echo "Get interface id for the network resource { az vm show --query } "
echo "*************************************************************"
cmd_status "az_vm_show_querynetworkinterface" az vm show --resource-group "${grpname}" --name "${vmname}"
interface_id=$(az vm show --resource-group "${grpname}" --name "${vmname}" --query networkProfile.networkInterfaces[0].id)
interface_id=${interface_id:1: -1}

echo "Get os disk id for the managedDisk { az vm show --query } "
echo "*************************************************************"
cmd_status "az_vm_show_querymanagedDisk" az vm show --resource-group "${grpname}" --name "${vmname}"
os_disk_id=$(az vm show --resource-group "${grpname}" --name "${vmname}" --query storageProfile.osDisk.managedDisk.id)
os_disk_id=${os_disk_id:1: -1}

echo "Get security group id { az vm show --query } "
echo "*************************************************************"
cmd_status "az_vm_show_querysecgrp" az vm show --resource-group "${grpname}" --name "${vmname}"
security_group_id=$(az network nic show --id "${interface_id}" --query networkSecurityGroup.id)
security_group_id=${security_group_id:1: -1}

echo "Get public ip id { az vm show --query } "
echo "*************************************************************"
cmd_status "az_vm_show_publicip" az vm show --resource-group "${grpname}" --name "${vmname}"
public_ip_id=$(az network nic show --id "${interface_id}" --query ipConfigurations[0].publicIpAddress.id)
public_ip_id=${public_ip_id:1: -1}

echo "Delete ${vmname} Virtual Machine { az vm delete } "
echo "*************************************************************"
cmd_status "az_vm_delete" az vm delete --resource-group "${grpname}" --name "${vmname}" --yes
echo "Deleted vm: ${vmname} in resource group ${grpname}"

echo "Delete nic ${interface_id} { az network nic delete } "
echo "*************************************************************"
cmd_status "az_network_nic_delete" az network nic delete --id "${interface_id}"
echo "Deleted network interface: ${interface_id}"

echo "Delete nic ${os_disk_id} { az disk delete } "
echo "*************************************************************"
cmd_status "az_disk_delete" az disk delete --id "${os_disk_id}" --yes
echo "Deleted os disk: ${os_disk_id}"

echo "Delete nsg ${security_group_id} { az network nsg delete } "
echo "*************************************************************"
cmd_status "az_network_nsg_delete" az network nsg delete --id "${security_group_id}"
echo "Deleted network security group: ${security_group_id}"

echo "Delete public ip ${public_ip_id} { az network public-ip delete } "
echo "********************************************************************"
cmd_status "az_network_public-ip_delete" az network public-ip delete --id "${public_ip_id}"
echo "Deleted public ip: ${public_ip_id}"

echo "List all resources for resource group ${grpname} { az resource list }"
echo "*******************************************************************"
for rid in $(az resource list --name "${grpname}" --query "reverse(sort_by([?contains(name, 'oqacli')].{name:name,time:createdTime,id:id}, &time))" -o tsv); do
    if [[ "${rid}" =~ .*"virtualNetworks".* ]]; then
       echo "Delete resource virtual network ${rid} { az network vnet delete }"
       echo "********************************************************************"
       cmd_status "az_network_vnet_delete" az network vnet delete --id "${rid}"
       echo "vnet deleted ${rid}"
    elif [[ "${rid}" =~ .*"disks".* ]]; then
       echo "Delete resource disk ${rid} { az disk delete }"
       echo "***********************************************"
       cmd_status "az_disk_delete" az disk delete --id "${rid}" --yes
       echo "disk deleted ${rid}"
    fi
done

#Reporting CLI test
echo "    Manage run commands using AZURE CLI Test Report                "
echo "*******************************************************************"
cli_test_report
