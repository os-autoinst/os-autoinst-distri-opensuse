#!/bin/bash -eu
set -o pipefail
# Create a vm and use run-command to execute RunShellscript
# list, show , delete the created resource

#Required AZ setting variable block
grpname="${1:-oqaclitest}"
location="${2:-westus}"
vmname="${3:-oqacliruncmdvm}"
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"

#local variable block
account="Azure RD"
admin="azureuser"
runcmd="oqaclirc"
cli_cnt=0
total_cnt=16
fail_cnt=0
cil_list=''

echo "**Start of AZURE CLI run-command test"
echo "*************************************"

# Resource creation
az account set -n "$account"
echo "Creating resource group"
let "cli_cnt+=1"
cli_list='az account set\n'

az group create -n $grpname -l $location -o table
echo "Created group $grpname"
let "cli_cnt+=1"
cli_list="$cli_list az group create\n"

#start vm provision
az vm create \
    --name $vmname \
    --resource-group $grpname \
    --location $location \
    --public-ip-sku Standard \
    --image $vmximagename \
    --generate-ssh-keys \
    --admin-username $admin \
    --enable-agent true \
    --enable-auto-update true \
    --size Standard_D2s_v3
echo "vm created"
let "cli_cnt+=1"
cli_list="$cli_list az vm create\n"

echo "Invoke run-command to change AutoUpdate.Enabled=y and restart waagent.service"
az vm run-command invoke \
    --command-id RunShellScript \
    --resource-group $grpname \
    --name $vmname \
    --scripts "cat /etc/waagent.conf"

az vm run-command invoke \
    --command-id RunShellScript \
    --resource-group $grpname \
    --name $vmname \
    --scripts "sed -i 's/AutoUpdate.Enabled=n/AutoUpdate.Enabled=y/g' /etc/waagent.conf"

az vm run-command invoke \
    --command-id RunShellScript \
    --resource-group $grpname \
    --name $vmname \
    --scripts "cat /etc/waagent.conf"

az vm run-command invoke \
   --command-id RunShellScript \
   --resource-group $grpname \
   --name $vmname \
   --scripts "sudo systemctl restart waagent.service"

az vm run-command invoke \
   --command-id RunShellScript \
   --resource-group $grpname \
   --name $vmname --scripts "sudo systemctl status waagent.service"

echo "Updated AutoUpdate.Enabled=y and restarted waagent.service"
let "cli_cnt+=1"
cli_list="$cli_list az vm run-command invoke\n"


echo "Create Run-command $runcmd "
az vm run-command create --name $runcmd -g $grpname --vm-name $vmname --script "echo Agent-status-ready'"
let "cli_cnt+=1"
cli_list="$cli_list az vm run-command create\n"

echo "List created Run-command $runcmd"
for cmdlist in $(az vm run-command list --vm-name $vmname -g $grpname --location $location --query "[].{name:name}" -o tsv); do 
    az vm run-command show -o table --vm-name $vmname -g $grpname --run-command-name $cmdlist --location $location
done
let "cli_cnt+=2"
cli_list="$cli_list az vm run-command list\n az vm run-command show\n"

echo "Delete Run-command $runcmd"
az vm run-command delete -g $grpname --run-command-name $runcmd --vm-name $vmname --yes -y
let "cli_cnt+=1"
cli_list="$cli_list az vm run-command delete\n"

echo "Delete vm and the associated resources like"
az resource list -o table -g oqaclitest --query "[?contains(name, 'oqacliruncmdvm')].{Name:name,Type:type}" -o tsv
let "cli_cnt+=1"
cli_list="$cli_list az resource list\n"

#Get required ids to delete the resource
interface_id=$(az vm show --resource-group $grpname --name $vmname --query networkProfile.networkInterfaces[0].id)
interface_id=${interface_id:1: -1}

os_disk_id=$(az vm show --resource-group ${grpname} --name ${vmname} --query storageProfile.osDisk.managedDisk.id)
os_disk_id=${os_disk_id:1: -1}
let "cli_cnt+=1"
cli_list="$cli_list az vm show\n"

security_group_id=$(az network nic show --id ${interface_id} --query networkSecurityGroup.id)
security_group_id=${security_group_id:1: -1}

public_ip_id=$(az network nic show --id ${interface_id} --query ipConfigurations[0].publicIpAddress.id)
public_ip_id=${public_ip_id:1: -1}
let "cli_cnt+=1"
cli_list="$cli_list az network nic show\n"

az vm delete --resource-group ${grpname} --name ${vmname} --yes
echo "Deleted vm: ${vmname} in resource group ${grpname}"
let "cli_cnt+=1"
cli_list="$cli_list az vm delete\n"

az network nic delete --id ${interface_id}
echo "Deleted network interface: ${interface_id}"
let "cli_cnt+=1"
cli_list="$cli_list az network nic delete\n"

az disk delete --id ${os_disk_id} --yes
let "cli_cnt+=1"
cli_list="$cli_list az disk delete\n"
echo "Deleted os disk: ${os_disk_id}"

az network nsg delete --id ${security_group_id}
let "cli_cnt+=1"
cli_list="$cli_list az network nsg delete\n"
echo "Deleted network security group:${security_group_id}"

az network public-ip delete --id ${public_ip_id}
let "cli_cnt+=1"
cli_list="$cli_list az network public-ip delete\n"
echo "Deleted public ip: ${public_ip_id}"

#Reporting CLI test
fail_cnt=$(( $total_cnt - $cli_cnt ))
echo "*****Azure run-command cli $total_cnt tests run, $cli_cnt passed and $fail_cnt failed*****"
echo "******************************************************************************************"
echo -e " $cli_list"
echo "******************************************************************************************"
