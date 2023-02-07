#!/bin/bash -eu
set -o pipefail
#create a role and configure to Resource group and assign role to subscription
#list, show and delete the created resource
#Report list of cli's used
#Role Base Access Control AZURE CLI testing script
#

#Required AZ setting variable block
grpname="${1:-oqaclitest}"
location="${2:-westus}"
vmname="${3:-oqaclivmss}"
ssh_key="${4:-oqaclitest-sshkey}"#
vmximagename="${5:-UbuntuLTS}"

# Variable block
account="Azure RD"
spname="oqaclitestsp"
config_file="azure_rbac.json"
role="oqaclitest-compute-access"
asptype="ServicePrincipal"
cli_cnt=0
total_cnt=20
fail_cnt=0
cli_list=''

# Resource creation
az account set -n "$account"
let "cli_cnt+=1"
cli_list='az account set\n'

echo "Creating resource group"
az group create -n $grpname -l $location
echo "Created group $grpname"
let "cli_cnt+=1"
cli_list="$cli_list az group create\n"
subid=$(az account list --query "[].{id:id}" -o tsv)

sed -i "s/rolename/$role/g" "$config_file"
sed -i "s/subid/$subid/g" "$config_file"
cat "$config_file"
echo "Creating role"
az role definition create --role-definition "$config_file"
echo "Created role "
echo "list Role"
az role definition list --custom-role-only true -g $grpname -n $role -o table
let "cli_cnt+=2"
cli_list="$cli_list az role definition create\n az role definition list\n"

echo "Create Service principal rbac and configure its access to resource group $grpname"
az ad sp create-for-rbac -n $spname --role oqaclitest-compute-access --scopes /subscriptions/$subid/resourceGroups/$grpname
let "cli_cnt+=2"
cli_list="$cli_list az ad sp create-for-rbac\n az account list\n"

echo "show created sp rbac access"
for splist in $(az ad sp list  --query "[?displayName=='$spname'].{id:appId}" --all -o tsv); do
    az ad sp show --id $splist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az ad sp list\n az ad sp show \n"

echo "Assign a role to group on a subscription"
for splist in $(az ad sp list  --query "[?displayName=='$spname'].{id:appId}" --all -o tsv); do
    az role assignment create --assignee-object-id $splist --assignee-principal-type $asptype --role $role -g $grpname
done
let "cli_cnt+=1"
cli_list="$cli_list az role assignment create\n"


echo "Delete $role assigned on a resource group or resource or subscription"
az role assignment delete --role $role -g $grpname
let "cli_cnt+=1"
cli_list="$cli_list az role assignment delete\n"

echo "Delete Service Principal rbac configuration and access to resource group $grpname"

for splist in $(az ad sp list  --query "[?displayName=='$spname'].{id:appId}" --all -o tsv); do
    az ad sp delete --id $splist
done
let "cli_cnt+=1"
cli_list="$cli_list az ad sp delete\n"

echo "Delete a role definition"
az role definition delete --name $role --subscription "$account"
let "cli_cnt+=1"
cli_list="$cli_list az role definition delete\n"

echo "Account and Subscription list and show"
for slist in $(az account subscription list --query "[].{id:subscriptionId}" -o tsv); do
    az account subscription show --id $slist -o table 
    az account subscription list-location --id $slist -o table
done
let "cli_cnt+=3"
cli_list="$cli_list az account subscription list\n az account subscription show\n az account subscription list-location\n"

for slist in $(az account list --query "[].{id:id}" -o tsv); do
    az account show -s $slist -o table 
    az account list-locations -o table
    az account alias list  -o table
    az account lock list -o table
done
let "cli_cnt+=5"
cli_list="$cli_list az account list\n az account show\n az account list-location\n az account alias list\n az account lock list\n"


#Reporting CLI test
fail_cnt=$(( $total_cnt - $cli_cnt ))
echo "*****Azure Role Base Access Control cli $total_cnt tests run, $cli_cnt passed and $fail_cnt failed*****"
echo "********************************************************************************************************"
echo -e " $cli_list"
echo "********************************************************************************************************"
