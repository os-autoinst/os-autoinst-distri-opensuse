#!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
#######################################################################
# File: azure_arm_sub.sh
# Command: azure_arm_sub.sh <resource groupname> <location> ..........
# Description: Tests Azure ARM Deployment at Subscription level.
#              azure_arm_sub_template.json creates resource group
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
# holds name for creating deployment, template and diretory for template 
# later used for invoking, listing, show, delete
sub_deployname="oqacliarmsubdeploy"
root_dir="/home/azureuser"
sub_template="${root_dir}/azure_arm_sub_template.json"

# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "${account}"
echo "Azure account set to ${account}"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "${grpname}" -l "${location}" -o table
echo "Created group ${grpname} in location ${location}"

echo "Validate Subscription template ${sub_template}"
cmd_status "az_dep_sub_val" az deployment sub validate --template-file ${sub_template} --location ${location}

echo "Create Subscription template ${sub_template}"
cmd_status "az_dep_sub_cre" az deployment sub create -n ${sub_deployname} --template-file ${sub_template} --location ${location}

echo "Export Subscription template ${sub_template}"
cmd_status "az_dep_sub_exp" az deployment sub export -n ${sub_deployname}

echo "List the resource created by the Subscription deployment template ${sub_template}"
cmd_status "az_grp_list" az group list -o table --query "[?contains(name, 'oqacliarm')].{Name:name,type:type}"

echo "List the Subscription deployment "
cmd_status "az_dep_sub_list" az deployment sub list -o table

echo "Show created deployment ${sub_deployname}"
cmd_status "az_dep_sub_show" az deployment sub show -n ${sub_deployname} -o table

echo "List the deployment operation subscription list"
cmd_status "az_dep_op_sub_list" az deployment operation sub list -n ${sub_deployname} -o table

echo "Show the deployment operation subscription list"
for oid in $(az deployment operation sub list -n ${sub_deployname} --query "[].{id:operationId}" -o tsv); do
   cmd_status "az_dep_op_sub_show" az deployment operation sub show -n ${sub_deployname} --operation-ids ${oid}
done

echo "Delete Subscription Deployment ${sub_deployname}"
cmd_status "az_dep_sub_del" az deployment sub delete -n ${sub_deployname} -o table

echo "Delete the resource created by the Subscription deployment template ${sub_template}"
cmd_status "az_grp_delete" az group delete -n ${grpname} --yes -y

#Reporting CLI test
echo "    ARM Deployment at Subscirption level using AZURE CLI Test Report      "
echo "*******************************************************************"
cli_test_report
