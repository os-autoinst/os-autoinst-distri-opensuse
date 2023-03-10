#!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
#create a virtual machine scale set
#list, show and delete the created resource
#Report list of cli's used

# Virtual Machine Scale Set AZURE CLI testing script

#Required AZ setting variable block
grpname="${1:-oqaclitest}"
location="${2:-westus}"
vmname="${3:-oqaclivmss}"
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"
account="${6:Azurerd}"

# Variable block
#account="Azure RD"
admin="azureuser"
policy="automatic"
inst_cnt=3
runcmd="oqaclircss"

# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "$account"

echo "Azure account set to $account"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "$grpname" -l "$location" -o table
echo "Created group $grpname"

echo "Creating VM Scale Set { az vmss create }"
cmd_status "az_vmss_create" az vmss create \
    --resource-group "$grpname" \
    --name "$vmname" \
    --image "$vmximagename" \
    --upgrade-policy-mode "$policy" \
    --instance-count "$inst_cnt" \
    --admin-username "$admin" \
    --generate-ssh-keys
echo "VM Scale set created"

echo " List all the resource created by VM scale set $vmname { az resource list }"
echo "***************************************************************************"
cmd_status "az_resource_list" az resource list
az resource list --query "[?contains(name, '$vmname')].{name:name,type:type}"

echo " List VM scaleset in the resource group $grpname { az vmss list }"
echo "*****************************************************************"
cmd_status "az_vmss_list" az vmss list -g "$grpname" -o table

echo " List vmss list instances for $vmname { az vmss list-instances }"
echo "*****************************************************************"
cmd_status "az_vmss_list-instances" az vmss list-instances -g "$grpname" --name "$vmname" -o table

echo " List vmss list instance connection info for $vmname { az vmss list-instance-connection-info }"
echo "**********************************************************************************************"
cmd_status "az_vmss_list-instance-connection-info" az vmss list-instance-connection-info -g "$grpname" --name "$vmname" -o table

echo " List vmss list instance public ips for $vmname { az vmss list-instance-public-ips }"
echo "************************************************************************************"
cmd_status "az_vmss_list-instance-public-ips" az vmss list-instance-public-ips -g "$grpname" --name "$vmname" -o table

echo " List vmss list skus for $vmname { az vmss list-skus }"
echo "******************************************************"
cmd_status "az_vmss_list-skus" az vmss list-skus -g "$grpname" --name "$vmname" -o table

echo " List vmss list nic for $vmname { az vmss nic list }"
echo "******************************************************"
cmd_status "az_vmss_nic_list" az vmss nic list -g "$grpname" --vmss-name "$vmname" -o table

echo " List vmss list-vm-nics for $vmname { az vmss nic list-vm-nics } "
cmd_status "az_vmss_nic_list-vm-nics" az vmss nic list-vm-nics -g "$grpname" --vmss-name "$vmname" --instance-id 4 -o table

echo " Restart $vmname { az vmss restart }"
cmd_status "az_vmss_restart" az vmss restart -g "$grpname" --name "$vmname"

echo " deallocate, stop and start $vmname "
cmd_status "az_vmss_list-instances" az vmss list-instances -g "$grpname" --name "$vmname"
for iid in $(az vmss list-instances -g $grpname --name $vmname --query "[].{instanceid:instanceId}" -o tsv); do
    echo " Deallocate vm's within VMSS instance id $iid { az vmss deallocate }"
    cmd_status "az_vmss_deallocate" az vmss deallocate --name "$vmname" -g "$grpname" --instance-ids "$iid"
    echo " Stop $vmname and instance id $iid { az vmss stop } "
    cmd_status "az_vmss_stop" az vmss stop -g "$grpname" --name "$vmname" --instance-ids "$iid"
    echo " Start $vmname of instance id $iid { az vmss start } "
    cmd_status "az_vmss_start" az vmss start -g "$grpname" --name "$vmname" --instance-ids "$iid" --no-wait
done

cmd_status "az_vmss_list-instances" az vmss list-instances -g "$grpname" --name "$vmname"
for iid in $(az vmss list-instances -g $grpname --name $vmname --query "[].{instanceid:instanceId}" -o tsv); do
    echo " Invoke Run command for instance id $iid { az vmss run-command invoke }"
    cmd_status "az_vmss_run-command_invoke" az vmss run-command invoke \
	           --command-id RunShellScript \
		   --resource-group "$grpname" \
		   --name "$vmname" \
		   --instance-id "$iid" \
		   --scripts "cat /etc/waagent.conf"
    echo "Create Run-command $runcmd for instance id $iid { az vmss run-command create } "
    cmd_status "az_vmss_run-command-create" az vmss run-command create \
	           --name "$runcmd" \
		   --resource-group "$grpname" \
		   --instance-id 1 \
		   --vmss-name "$vmname" \
		   --instance-id "$iid" \
		   --script "echo Agent-status-ready"
    echo "List created Run-command $runcmd for instance id $iid { az vmss run-command list }"
    cmd_status "az_vmss_run-command_list" az vmss run-command list -g "$grpname" --vmss-name "$vmname" --instance-id "$iid"
    for cmdlist in $(az vmss run-command list --vmss-name $vmname -g $grpname --instance-id $iid --query "[].{name:name}" -o tsv); do 
        echo "Show Run-command $cmdlist { az vmss run-command show }"
        cmd_status "az_vmss_run-command_show" az vmss run-command show -o table \
	               --vmss-name "$vmname" \
		       --resource-group "$grpname" \
		       --run-command-name "$cmdlist" \
		       --instance-id "$iid"
    done
    echo "Delete Run-command $runcmd for instance id $iid { az vmss run-command delete }"
    cmd_status "az_vmss_run-command_delete" az vmss run-command delete \
	           --resource-group "$grpname" \
		   --run-command-name "$runcmd" \
		   --vmss-name "$vmname" \
		   --instance-id "$iid" \
		   --yes -y
done

echo "Change the number of VM's within VMSS { az vmss scale }"
cmd_status "az_vmss_scale" az vmss scale --name "$vmname" --new-capacity 5 --resource-group "$grpname"

echo "Show the vm's within vmss { az vmss show }"
cmd_status "az_vmss_show " az vmss show --name "$vmname" -g "$grpname" -o table

echo "Delete the vm's within vmss { az vmss delete }"
cmd_status "az_vmss_delete" az vmss delete -n "$vmname" -g "$grpname" --force-deletion yes

echo "List all resources for resource group $grpname { az resource list }"
echo "*******************************************************************"
for rid in $(az resource list -o table --query "reverse(sort_by([?contains(name, 'oqaclivmss')].{name:name,time:createdTime,id:id}, &time))" -o tsv);
do
    if [[ "$rid" =~ .*"virtualNetworks".* ]]; then
       echo "Delete resource virtual network ${rid} { az network vnet delete }"
       echo "********************************************************************"
       cmd_status "az_network_vnet_delete" az network vnet delete --id "$rid"
       echo "vnet deleted ${rid}"
    fi
done

echo "             Azure Virtual Machine Scale Set cli Test Report         "
echo "*********************************************************************"
final_exit
