##!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
############################################################################
# File: azure_rbac.sh
# Description: Tests a rbac azure cli's.
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
############################################################################

# Virtual Machine Scale Set AZURE CLI testing script

# Required AZ setting variable block with default values
grpname="${1:-oqaclitest}"
location="${2:-westus}"
vmname="${3:-oqaclivmss}"
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"
account="${6:-5f40eec9-a9be-4851-90c1-621e6d65df81}"
admin="${7:-azureuser}"

#
# Role Base Access Control AZURE CLI testing script

root_dir='/home/azureuser'

# Variable block
# Role name , Config file, Service Principal name
spname="oqaclitestsp"
config_file="${root_dir}/rbac.config"
role="oqaclitest-compute-access"


# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "${account}"
echo "Azure account set to ${account}"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "${grpname}" -l "${location}" -o table
echo "Created group ${grpname} in location ${location}"


echo "Creating role"
cmd_status "az_role_def_create" az role definition create --role-definition ${config_file}

echo "List role ${role}"
cmd_status "az_role_def_list" az role definition list -g ${grpname} -n ${role} -o table

echo "Create Service principal rbac and configure its access to resource group ${grpname}"
cmd_status "az_ad_sp_crbac" az ad sp create-for-rbac -n ${spname} --role oqaclitest-compute-access --scopes /subscriptions/${account}/resourceGroups/${grpname}

echo "Show created sp rbac access"
splist=$(az ad sp list  --query "[?displayName=='${spname}'].{id:appId}" --all -o tsv)
cmd_status "az_ad_sp_show" az ad sp show --id ${splist} -o table

echo "Assign a role to group on a subscription"
cmd_status "az_role_ass_create" az role assignment create --assignee-object-id ${splist} --assignee-principal-type "ServicePrincipal" --role ${role} -g ${grpname}

echo "Delete ${role} assigned on a resource group or resource or subscription"
az role assignment delete --role ${role} -g ${grpname}

echo "Delete Service Principal rbac configuration and access to resource group ${grpname}"
cmd_status "az_ad_sp_delete" az ad sp delete --id ${splist}

echo "Delete a role definition"
cmd_status "az_role_def_delete" az role definition delete --name ${role} --subscription "${account}"

echo "**                       AZURE Cli RBAC test report                **"
echo "*********************************************************************"
cli_test_report
