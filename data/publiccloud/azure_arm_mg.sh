#!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
#######################################################################
# File: azure_arm_mg.sh
# Command: azure_arm_mg.sh <resource groupname> <location> ..........
# Description: Tests Azure ARM deployment at Management level using cli.
#              azure_arm_mg_template.json creates management group with 
#              policy and allowing for specific locations as per the policy
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
# holds name for creating deployment,template and location of template json
# later used for invoking, listing, show, delete
mg_deployment="oqacliarmgrpdeploy"
mg_name="oqacliarmmg"
root_dir="/home/azureuser"
mg_template="${root_dir}/azure_arm_mg_template.json"

# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "${account}"
echo "Azure account set to ${account}"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "${grpname}" -l "${location}" -o table
echo "Created group ${grpname} in location ${location}"

echo "Create Managmenet group ${mg_name}"
cmd_status "az_acct_mg_create" az account management-group create -n ${mg_name} -d ${mg_name}

echo "List Management group ${mg_name}"
cmd_status "az_acct_mg_list" az account management-group list -o table

echo "Show Managment group ${mg_name}"
cmd_status "az_acct_mg_show" az account management-group show -n ${mg_name} -o table

echo "Validate template management group ${mg_template}" 
cmd_status "az_dep_mg_val" az deployment mg validate --template-file ${mg_template} --location ${location} -m ${mg_name} -p targetMG=${mg_name}

echo "Create template management group ${mg_template}" 
cmd_status "az_dep_mg_cre" az deployment mg create --template-file ${mg_template} --location ${location} -m ${mg_name} -n ${mg_deployment} -p targetMG=${mg_name}

echo "Export template management group ${mg_template}" 
cmd_status "az_dep_mg_exp" az deployment mg export -m ${mg_name} -n ${mg_deployment}

echo "List & Show the policy created by Management template"
cmd_status "az_pol_def_list" az policy definition list --management-group ${mg_name} --query "[?contains(name, 'oqacliarm')].{Name:name}" -o table

for pid in $(az policy definition list --management-group ${mg_name} --query "[?contains(name, 'oqacliarm')].{Name:name}" -o tsv); do
    cmd_status "az_pol_def_show" az policy definition show --management-group ${mg_name} --name ${pid}
done

echo "List the Management template ${mg_deployment}"
cmd_status "az_dep_mg_list" az deployment mg list --management-group-id ${mg_name} -o table 

echo "Show the Managnement template ${mg_deployment}"
for mgid in $(az deployment mg list --management-group-id ${mg_name} --query "[].{Name:name}" -o tsv); do 
    cmd_status "az_dep_mg_show" az deployment mg show --name ${mgid} --management-group-id ${mg_name} -o table
done

echo "List the deployment operation Mangament Group list"
cmd_status "az_dep_op_mg_list" az deployment operation mg list -m ${mg_name} -n ${mg_deployment} -o table

echo "Show the deployment operation Management Group list"
for oid in $(az deployment operation mg list -m ${mg_name} -n ${mg_deployment} --query "[].{id:operationId}" -o tsv); do
   az deployment operation mg show -m ${mg_name} -n ${mg_deployment} --operation-ids ${oid} -o table
done

echo "Delete the created policy by Mangaement deployment"
for pid in $(az policy definition list --management-group ${mg_name} --query "[?contains(name, 'oqacliarm')].{Name:name}" -o tsv); do
    az policy definition delete --management-group ${mg_name} --name ${pid}
done  

echo "Delete the created template ${mg_deployment}"
for mgid in $(az deployment mg list --management-group-id $mg_name --query "[].{Name:name}" -o tsv); do 
    az deployment mg delete --name ${mgid} --management-group-id ${mg_name}
done

echo "Delete the Management group ${mg_name}"
az account management-group delete -n ${mg_name}

#Reporting CLI test
echo "    ARM Deployment at Management level using AZURE CLI Test Report      "
echo "*******************************************************************"
cli_test_report
