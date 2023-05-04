#!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
#######################################################################
# File: azure_arm_grp.sh
# Command: azure_arm_grp.sh <resource groupname> <location> ..........
# Description: Tests Azure ARM deployment at Group level using cli.
#              azure_arm_grp_template.json creates vm,sshkey,publicip, 
#              virtual networks and security groups.
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
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"
account="${6:-5f40eec9-a9be-4851-90c1-621e6d65df81}"
admin="${7:-azureuser}"

# local variable block
# holds name for creating deployment, template and directory for json
# later used for invoking, listing, show, delete
grp_deployname="oqacliarmgrpdeploy"
root_dir="/home/azureuser"
grp_template="${root_dir}/azure_arm_grp_template.json"

# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "${account}"
echo "Azure account set to ${account}"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "${grpname}" -l "${location}" -o table
echo "Created group ${grpname} in location ${location}"

echo "Validate template group ${grp_template}"
cmd_status "az_dep_grp_val" az deployment group validate --resource-group ${grpname} --template-file ${grp_template}

echo "Create template group ${grp_template}"
cmd_status "az_grp_create" az deployment group create --resource-group ${grpname} -n ${grp_deployname} --template-file ${grp_template}

echo "Export template group ${grp_template}"
cmd_status "az_dep_grp_exp" az deployment group export -n ${grp_deployname} -g ${grpname} 

echo "List the resource created by the deployment group template ${grp_template}"
cmd_status "az_res_list" az resource list -o table --query "[?contains(name, 'oqacliarm')].{Name:name}" -o table

echo "List the deployment group "
cmd_status "az_dep_grp_list" az deployment group list --resource-group ${grpname} --query "[?contains(type, 'Microsoft.Resources/deployments')].{type:type,Name:name,State:properties.provisioningState}" -o table

echo "Show created deployment group ${grp_deployname}"
cmd_status "az_dep_grp_show" az deployment group show --resource-group ${grpname} --name ${grp_deployname} -o table

echo "List the deployment operation group list"
cmd_status "az_dep_op_grp_list" az deployment operation group list --resource-group ${grpname} --name ${grp_deployname} -o table

echo "Show the deployment operation group list"
for oid in $(az deployment operation group list --resource-group ${grpname} -n ${grp_deployname} --query "[].{id:operationId}" -o tsv); do
   cmd_status "az_dep_op_grp_show" az deployment operation group show -n ${grp_deployname} --resource-group ${grpname} --operation-ids ${oid}
done

echo "Delete Deployment group ${grp_deployname}"
cmd_status "az_dep_grp_del" az deployment group delete --resource-group ${grpname} -n ${grp_deployname}

echo "Delete the resource created by the deployment group template ${grp_template}"
echo "Deleting ..."
diskid="0"
# list the resource name starts with oqacliarm sort by created time,id,name and reverse the order
# Delete Disk after deleting the VM
# grep only the resource id
#for rid in $(az resource list --query "reverse(sort_by([?contains(name, 'oqacliarm')].{name:name,time:createdTime,id:id}, &time))" -o tsv | awk '{print $3}'); do
for rid in $(az resource list --query "[?contains(name, 'oqacliarm')].{id:id}" -o tsv); do
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
            diskid=${rid}
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
      *)
            echo "Unknown RID type ${rid}"
   esac
done

echo "Delete Disk $diskid"
cmd_status "az_disk_delete" az disk delete --id $diskid --yes

echo "Delete group ${grpname} "
cmd_status "az_grp_delete" az group delete -n ${grpname} --yes -y

#Reporting CLI test
echo "    ARM Deployment at Group level using AZURE CLI Test Report      "
echo "*******************************************************************"
cli_test_report
