#!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
#######################################################################
# File: azure_lb.sh
# Command: azure_lb.sh <resource groupname> <location> ..........
# Description: Tests Azure load Balancer using cli.
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
vmname="${3:-oqaclilbvm}"
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"
account="${6:-5f40eec9-a9be-4851-90c1-621e6d65df81}"
admin="${7:-azureuser}"

# Variable block
#stores names with random identifier
let "randomIdentifier=$RANDOM"
vNet="msdocs-vnet-lb-${randomIdentifier}"
subnet="msdocs-subnet-lb-${randomIdentifier}"
loadBalancerPublicIp="msdocs-public-ip-lb-${randomIdentifier}"
loadBalancer="msdocs-load-balancer-${randomIdentifier}"
frontEndIp="msdocs-front-end-ip-lb-${randomIdentifier}"
backEndPool="msdocs-back-end-pool-lb-${randomIdentifier}"
probe80="msdocs-port80-health-probe-lb-${randomIdentifier}"
loadBalancerRuleWeb="msdocs-load-balancer-rule-port80-${randomIdentifier}"
loadBalancerRuleSSH="msdocs-load-balancer-rule-port22-${randomIdentifier}"
networkSecurityGroup="msdocs-network-security-group-lb-${randomIdentifier}"
networkSecurityGroupRuleSSH="msdocs-network-security-rule-port22-lb-${randomIdentifier}"
networkSecurityGroupRuleWeb="msdocs-network-security-rule-port80-lb-${randomIdentifier}"
nic="msdocs-nic-lb-${randomIdentifier}"
availabilitySet="msdocs-availablity-set-lb-${randomIdentifier}"
tag="create-vm-nlb"
ipSku="Standard"

# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "${account}"
echo "Azure account set to ${account}"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "${grpname}" -l "${location}" -o table
echo "Created group ${grpname} in location ${location}"

# Create a virtual network and a subnet.
echo "Creating vnet "
cmd_status "az_net_vnet_create" az network vnet create --resource-group ${grpname} --location "${location}" --name ${vNet} --subnet-name ${subnet}

## Show vnet using first item returned from net list
echo "Network vnet list & show"
echo "***************************"
vnlist=$( az network vnet list -g ${grpname} --query "[].{name:name}" -o tsv | head -n 1)
cmd_status "az_net_vnet_show" az network vnet show -n ${vnlist} -g ${grpname} -o table

# Create a public IP address for load balancer.
echo "Creating $loadBalancerPublicIp"
cmd_status "az_net_pubip_create" az network public-ip create --resource-group ${grpname} --name ${loadBalancerPublicIp}

## Show public-ip using first item returned from public-ip list
echo "Network public-ip list & show"
echo "***************************"
iplist=$(az network public-ip list -g ${grpname} --query "[].{name:name}" -o tsv | head -n 1)
cmd_status "az_net_pubip_show" az network public-ip show -n ${iplist} -g ${grpname} -o table


# Create an Azure Load Balancer.
echo "Creating ${loadBalancer} with ${frontEndIp} and ${backEndPool}"
cmd_status "az_net_lb_create" az network lb create \
    --resource-group "${grpname}" \
    --name "${loadBalancer}" \
    --public-ip-address "${loadBalancerPublicIp}" \
    --frontend-ip-name "${frontEndIp}" \
    --backend-pool-name "${backEndPool}" \
    --output table

echo "Load Balancer list & show"
echo "***************************"
cmd_status "az_net_lb_show" az network lb show --name "${loadBalancer}" --resource-group "${grpname}" -o table

# Create an LB probe on port 80.
echo "Creating ${probe80} in ${loadBalancer}"
cmd_status "az_net_lb_pr_create" az network lb probe create \
   --resource-group "${grpname}" \
   --lb-name "${loadBalancer}" \
   --name "${probe80}" \
   --protocol tcp \
   --port 80

echo "LB probe list & show"
echo "***************************"
cmd_status "az_net_lb_pr_show" az network lb probe show \
   --name "${probe80}" \
   --resource-group "${grpname}"  \
   --lb-name "${loadBalancer}" \
   --output table


# Create an LB rule for port 80.
echo "Creating ${loadBalancerRuleWeb} for ${loadBalancer}"
cmd_status "az_net_lb_rule_create" az network lb rule create \
   --resource-group "${grpname}"  \
   --lb-name "${loadBalancer}" \
   --name "${loadBalancerRuleWeb}" \
   --protocol tcp \
   --frontend-port 80 \
   --backend-port 80 \
   --frontend-ip-name "${frontEndIp}" \
   --backend-pool-name "${backEndPool}" \
   --probe-name "${probe80}" \
   --output table

echo "LB rule list & show"
echo "***************************"
iplist=$(az network lb rule list -g ${grpname} --lb-name ${loadBalancer} --query "[].{name:name}" -o tsv | head -n 1)
cmd_status "az_net_lb_rule_show" az network lb rule show \
   --name "${iplist}" \
   --resource-group "${grpname}" \
   --lb-name "${loadBalancer}" \
   --output table

# Create three NAT rules for port 22.
echo "Creating three NAT rules named ${loadBalancerRuleSSH}1 - ${loadBalancerRuleSSH}3"
for i in `seq 1 3`; do
  cmd_status "az_net_lb_innat_rule" az network lb inbound-nat-rule create \
     --resource-group "${grpname}" \
     --lb-name "${loadBalancer}" \
     --name "${loadBalancerRuleSSH}${i}" \
     --protocol tcp \
     --frontend-port "422${i}" \
     --backend-port 22 \
     --frontend-ip-name "${frontEndIp}" \
     --output table
done

echo "LB rule list & show"
echo "***************************"
iplist=$(az network lb inbound-nat-rule list -g ${grpname} --lb-name ${loadBalancer} --query "[].{name:name}" -o tsv | head -n 1)
cmd_status "az_net_lb_innat_rule_show" az network lb inbound-nat-rule show --name ${iplist} -g ${grpname} --lb-name ${loadBalancer} -o table

# Create a network security group
echo "Creating ${networkSecurityGroup}"
cmd_status "az_net_nsg_create" az network nsg create --resource-group ${grpname} --name ${networkSecurityGroup}

# Create a network security group rule for port 22.
echo "Creating ${networkSecurityGroupRuleSSH} in ${networkSecurityGroup} for port 22"
cmd_status "az_net_nsg_rule_create22" az network nsg rule create \
   --resource-group "${grpname}" \
   --nsg-name "${networkSecurityGroup}" \
   --name "${networkSecurityGroupRuleSSH}" \
   --protocol tcp \
   --direction inbound \
   --source-address-prefix '*' \
   --source-port-range '*' \
   --destination-address-prefix '*' \
   --destination-port-range 22 \
   --access allow \
   --priority 1000 \
   --output table
  

# Create a network security group rule for port 80.
echo "Creating ${networkSecurityGroupRuleWeb} in ${networkSecurityGroup} for port 80"
cmd_status "az_net_nsg_rule_create80" az network nsg rule create \
   --resource-group "${grpname}" \
   --nsg-name "${networkSecurityGroup}" \
   --name "${networkSecurityGroupRuleWeb}" \
   --protocol tcp \
   --direction inbound \
   --priority 1001 \
   --source-address-prefix '*' \
   --source-port-range '*' \
   --destination-address-prefix '*' \
   --destination-port-range 80 \
   --access allow --priority 2000 \
   --output table

# Create three virtual network cards and associate with public IP address and NSG.
echo "Creating three NICs named ${nic}1 - ${nic}3 for $vNet and $subnet"
for i in `seq 1 3`; do
  cmd_status "az_net_nic_create" az network nic create \
     --resource-group "${grpname}" \
     --name "${nic}${i}" \
     --vnet-name "${vNet}" \
     --subnet "${subnet}" \
     --network-security-group "${networkSecurityGroup}" \
     --lb-name "${loadBalancer}" \
     --lb-address-pools "${backEndPool}" \
     --lb-inbound-nat-rules "${loadBalancerRuleSSH}${i}" \
     --output table
done
   
# Create an availability set.
echo "Creating ${availabilitySet}"
cmd_status "az_vm_avset_create" az vm availability-set create \
     --resource-group "${grpname}" \
     --name "${availabilitySet}" \
     --platform-fault-domain-count 3 \
     --platform-update-domain-count 3 \
     --output table

echo "LB availability-set and list-sizes list & show"
echo "**********************************************"
for iplist in $(az vm availability-set list -g ${grpname} --query "[].{name:name}" -o tsv); do
    cmd_status "az_vm_avset_show" az vm availability-set show --name ${iplist} -g ${grpname} -o table
    cmd_status "az_vm_avset_list_sizes" az vm availability-set list-sizes --name ${iplist} -g ${grpname}
done

# Create three virtual machines, this creates SSH keys if not present.
echo "Creating three VMs named ${vmname}1 - ${vmname}3 with ${nic}1 - ${nic}3 using ${vmximagename}"
for i in `seq 1 3`; do
  cmd_status "az_vm_create" az vm create \
     --resource-group "${grpname}" \
     --name "${vmname}${i}" \
     --availability-set "${availabilitySet}" \
     --nics "${nic}${i}" \
     --image "${vmximagename}" \
     --public-ip-sku "${ipSku}" \
     --admin-username "${admin}" \
     --generate-ssh-keys \
     --no-wait \
     --output table
done

# List the virtual machines
az vm list --resource-group ${grpname}

echo "Delete the resource created by the loadbalancer "
echo "Deleting ..."
declare -a diskids=()
# list the resource name starts with oqacli
# Delete Disk after deleting the VM
for rid in $(az resource list --query "[?contains(name, 'oqacli')].{id:id}" -o tsv); do
case "${rid}" in
      *"publicIPAddresses"*)
            cmd_status "az_net_pubip_del" az network public-ip delete --id ${rid}
            echo "public-ip deleted " ${rid}
            ;;
      *"virtualMachines"*)
            cmd_status "az_vm_delete" az vm delete --ids ${rid} --yes
            echo "vm deleted " ${rid}
            ;;
      *"disks"* )
            diskids+=${rid}
            ;;
      *"networkSecurityGroups"*)
            cmd_status "az_net_nsg_del" az network nsg delete --id ${rid}
            echo "nsg deleted " ${rid}
            ;;
      *"networkInterfaces"*)
            cmd_status "az_net_nic_del" az network nic delete --id ${rid}
            echo "nic deleted " ${rid}
            ;;
      *"virtualNetworks"*)
            cmd_status "az_net_vnet_del" az network vnet delete --id ${rid}
            echo "vnet deleted " ${rid}
            ;;
      *"sshPublicKeys"*)
            cmd_status "az_sshkey_del" az sshkey delete --id ${rid} --yes
            echo "publickey deleted " ${rid}
            ;;
      *"availabilitySets".*)                                                                                                                  
            cmd_status "az_vm_avset_delete" az vm availability-set delete --ids ${rid}
            echo "availabilty set deleted"
	    ;;
      *)
            echo "Unknown RID type ${rid}"
   esac
done

for dkid in "${diskids[@]}"
do
  echo "Delete Disk ${dkid}"
  cmd_status "az_disk_delete" az disk delete --id ${dkid} --yes
done

echo "Delete group ${grpname} "
cmd_status "az_grp_delete" az group delete -n ${grpname} --yes -y

# Reporting CLI test
echo "     AZURE CLI Load Balancer Test Report      "
echo "**********************************************"
cli_test_report
