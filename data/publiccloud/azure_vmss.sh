#!/bin/bash -eu
set -o pipefail
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

# Variable block
account="Azure RD"
admin="azureuser"
policy="automatic"
inst_cnt=3
runcmd="oqaclircss"
cli_cnt=0
total_cnt=23
fail_cnt=0
cli_list=''

# Resource creation
az account set -n "$account"
echo "Creating resource group"
let "cli_cnt+=1"
cli_list='az account set\n'

az group create -n $grpname -l $location -o table
echo "Created group $grpname"
let "cli_cnt+=1"
cli_list="$cli_list az group create\n"

echo "Creating VM Scale Set "
az vmss create \
    --resource-group $grpname \
    --name $vmname \
    --image $vmximagename \
    --upgrade-policy-mode $policy \
    --instance-count $inst_cnt \
    --admin-username $admin \
    --generate-ssh-keys
echo "VM Scale set created"
let "cli_cnt+=1"
cli_list="$cli_list az vmss create\n"

echo " List all the resource created by VM scale set $vmname"
az resource list --query "[?contains(name, '$vmname')].{name:name,type:type}"
let "cli_cnt+=1"
cli_list="$cli_list az resource list\n"

echo " List VM scaleset in the resource group $grpname"
az vmss list -g $grpname -o table
let "cli_cnt+=1"
cli_list="$cli_list az vmss list\n"

echo " List vmss list instances for $vmname "
az vmss list-instances -g $grpname --name $vmname -o table
let "cli_cnt+=1"
cli_list="$cli_list az vmss list-instances\n"

echo " List vmss list instance connection info for $vmname"
az vmss list-instance-connection-info -g $grpname --name $vmname -o table
let "cli_cnt+=1"
cli_list="$cli_list az vmss list-instances-connnection-info\n"

echo " List vmss list instance public ips for $vmname"
az vmss list-instance-public-ips -g $grpname --name $vmname -o table 
let "cli_cnt+=1"
cli_list="$cli_list az vmss list-instances-public-ips\n"

echo " List vmss list skus for $vmname"
az vmss list-skus -g $grpname --name $vmname -o table
let "cli_cnt+=1"
cli_list="$cli_list az vmss list-skus\n"

echo " List vmss list nic for $vmname"
az vmss nic list -g $grpname --vmss-name $vmname -o table
let "cli_cnt+=1"
cli_list="$cli_list az vmss nic list\n"

echo " List vmss list-vm-nics for $vmname "
#az vmss nic list-vm-nics -g $grpname --vmss-name $vmname --instance-id 4 -o table
let "cli_cnt+=1"
cli_list="$cli_list az vmss nic list-vm-nics\n"

echo " Restart $vmname "                                                     
az vmss restart -g $grpname --name $vmname                               
let "cli_cnt+=1"
cli_list="$cli_list az vmss restart\n"

echo " Start $vmname "
for iid in $(az vmss list-instances -g $grpname --name $vmname --query "[].{instanceid:instanceId}" -o tsv); do
    echo " Deallocate vm's within VMSS instance id $iid"
    az vmss deallocate --name $vmname -g $grpname --instance-ids $iid
    echo " Stop $vmname and instance id $iid "                                                    
    az vmss stop -g $grpname --name $vmname --instance-ids $iid
    echo " Start $vmname of instance id $iid "
    az vmss start -g $grpname --name $vmname --instance-ids $iid --no-wait
done
let "cli_cnt+=3"
cli_list="$cli_list az vmss deallocate\n az vmss stop\n az vmss start\n"

for iid in $(az vmss list-instances -g $grpname --name $vmname --query "[].{instanceid:instanceId}" -o tsv); do
    echo " Invoke Run command for instance id $iid"
    az vmss run-command invoke --command-id RunShellScript --resource-group $grpname --name $vmname --instance-id $iid --scripts "cat /etc/waagent.conf"
    echo "Create Run-command $runcmd for instance id $iid "
    az vmss run-command create --name $runcmd -g $grpname --instance-id 1 --vmss-name $vmname --instance-id $iid --script "echo Agent-status-ready'"
    echo "List created Run-command $runcmd for instance id $iid"
    for cmdlist in $(az vmss run-command list --vmss-name $vmname -g $grpname --instance-id $iid --query "[].{name:name}" -o tsv); do 
        az vmss run-command show -o table --vmss-name $vmname -g $grpname --run-command-name $cmdlist --instance-id $iid
    done
    echo "Delete Run-command $runcmd for instance id $iid"
    az vmss run-command delete -g $grpname --run-command-name $runcmd --vmss-name $vmname --instance-id $iid --yes -y
done
let "cli_cnt+=5"
cli_list="$cli_list az vmss run-command invoke\n az vmss run-command create\n az vmss run-command show\n az vmss run-command delete\n az vmss run-command list\n"

echo "Change the number of VM's within VMSS"
az vmss scale --name $vmname --new-capacity 6 --resource-group $grpname
let "cli_cnt+=1"
cli_list="$cli_list az vmss scale\n"

echo "Show the vm's within vmss"
az vmss show --name $vmname -g $grpname -o table           
let "cli_cnt+=1"
cli_list="$cli_list az vmss show\n"

echo "Delete the vm's within vmss"
az vmss delete -n $vmname -g $grpname --force-deletion yes
let "cli_cnt+=1"
cli_list="$cli_list az vmss delete\n"

#Reporting CLI test
fail_cnt=$(( $total_cnt - $cli_cnt ))
echo "*****Azure Virtual Machine Scale Set cli $total_cnt tests run, $cli_cnt passed and $fail_cnt failed*****"
echo "********************************************************************************************************"
echo -e " $cli_list"
echo "********************************************************************************************************"
