#!/bin/bash -eu
set -o pipefail
# Create a VM with multiple subnets and public ip
# maximize the usage of azure cli network
# list, show , delete the created resource

# Virtual Network AZURE CLI testing script

#Required AZ setting variable block
grpname="${1:-oqaclitest}"
location="${2:-westus}"
vmname="${3:-oqaclivm}"
ssh_key="${4:-oqaclitest-sshkey}"
vmximagename="${5:-UbuntuLTS}"

# Variable block
account="Azure RD"
admin="azureuser"
stor="stor"
cont="cont"
storageacc=$grpname$stor
STORAGE_CONT=$grpname$cont
number_of_nics=2
addressprefix="30.0.0.0/16"
PrivateIpAddress="30.0.0.10"
PrivateIpAddress2="30.0.1.10"
subnet_prefixes=( 30.0.0.0/24 30.0.1.0/24 )
#vmximagename="oqacli-image-20230127175309"
vnet=$grpname-vnet1
base_subnet=$vnet-vsubnet
base_nic=$vmname-wan-nic
mdisk="_Managed_Disk"
cli_cnt=0
total_cli=49
fail_cnt=0
cli_list=''
echo "**Start of AZURE CLI Virtual Network test**"
echo "*******************************************"

# Resource creation
az account set -n "$account"
let "cli_cnt+=1"
cli_list='az account set\n'

echo "Creating resource group"
az group create -n $grpname -l $location -o table
cli_list="$cli_list az group create\n"
let "cli_cnt+=1"
echo "Created group $grpname"

echo "Creating storage account"
# Create storage account
az storage account create --sku Standard_LRS --location $location --kind Storage --resource-group $grpname --name $storageacc --output table
let "cli_cnt+=1"
cli_list="$cli_list az storage acccount create\n"
echo "Created storage account $storageacc"

# Get connection string for the storage account 
KEY1=`az storage account keys list --account-name $storageacc --resource-group $grpname  | grep -m 1 \"value\": | awk '{print $2}'`
let "cli_cnt+=1"
cli_list="$cli_list az storage acccount keys list\n"

# Create storage container
az storage container create --account-name $storageacc --name $STORAGE_CONT --account-key $KEY1 --output table
let "cli_cnt+=1"
cli_list="$cli_list az storage container create\n"
echo "Created container $STORAGE_CONT"

count=$(( $number_of_nics - 1 ))
while [ $count -ge 0 ]
do
    subnet_names[$count]=$base_subnet"$count"
    nic_names[$count]=$base_nic"$count"
    count=$(( $count - 1 ))
done

skip=1
echo "Check vnet exists for $grpname and $vnet "
az network vnet show -g $grpname  --name  $vnet > /dev/null 2>&1 && skip=2;echo "Vnet \"$vnet\" already exists, skipping vnet and subnet creation"|| skip=1
cli_list="$cli_list az network vnet show\n"
let "cli_cnt+=1"
echo "Skip value $skip"
if [ $skip -eq 1 ]; then
    # Create VNET
    echo "Creating Azure virtual network $vnet...."
    az network vnet create \
        --resource-group $grpname \
        --name $vnet \
        --address-prefix $addressprefix \
        --location $location \
        --output table

    let "cli_cnt+=1"
    cli_list="$cli_list az network vnet create\n"
    echo "Done creating Azure virtual network $vnet"

    # Create as many subnets as there are NICs
    i=0
    echo "subnetprefix" ${subnet_prefixes[@]}
    for prefix in "${subnet_prefixes[@]}"
    do
        echo "Creating virtual subnet ${subnet_names[$i]} $prefix.."
        az network vnet subnet create \
            --address-prefix $prefix \
            --name ${subnet_names[$i]} \
            --resource-group $grpname \
            --vnet-name $vnet \
            --output table
        echo "Done creating subnet ${subnet_names[$i]} with prefix $prefix and $i"
	let "i+=1"
    done
    let "cli_cnt+=1"
    cli_list="$cli_list az network vnet subnet create\n"
fi

#
# Creating routing tables for vMX WAN ports (add tables as needed for more than 2 wan ports)
#
echo "Creating routing tables..."

az network route-table create --name $grpname-rt-to-subnet2 --resource-group $grpname --location $location --output table
az network route-table create --name $grpname-rt-to-subnet3 --resource-group $grpname --location $location --output table
let "cli_cnt+=1"
cli_list="$cli_list az network route-table create\n"



az network vnet subnet update --resource-group $grpname --vnet-name $vnet --name $vnet-vsubnet0 --route-table $grpname-rt-to-subnet3 --output table
az network vnet subnet update --resource-group $grpname --vnet-name $vnet --name $vnet-vsubnet1 --route-table $grpname-rt-to-subnet2  --output table
let "cli_cnt+=1"
cli_list="$cli_list az network vnet subnet update\n"
#
# Create all NICs
#

echo "Creating public IP addresses and NICs..."

i=0
allnics=""
for nic in "${nic_names[@]}"
do
    if [ $i -eq 0 ]; then
        # Create Public IP for first NIC:
        ip=$vmname-vfp-public-ip
        az network public-ip create \
            --name $ip \
            --allocation-method Static \
            --resource-group $grpname \
            --location $location \
            --output table

        # Create 1st NIC
	nic=$vmname-vfp-nic
        allnics="$allnics ""$nic"
        az network nic create \
            --resource-group $grpname \
            --location $location \
            --name $nic \
            --vnet-name $vnet \
            --subnet ${subnet_names[$i]} \
            --public-ip-address $ip \
            --private-ip-address $PrivateIpAddress \
            --output table
        echo "Created NIC $nic with public IP..."

    elif [ $i -eq 1 ]; then
        # Create Public IP for first NIC:
        ip2=$vmname-vcp-public-ip
        az network public-ip create \
            --name $ip2 \
            --allocation-method Static \
            --resource-group $grpname \
            --location $location \
            --output table

        # Create 2nd NIC
	nic=$vmname-vcp-nic
        allnics="$allnics ""$nic"
        az network nic create \
            --resource-group $grpname \
            --location $location \
            --name $nic \
            --vnet-name $vnet \
            --subnet ${subnet_names[$i]} \
            --public-ip-address $ip2 \
            --private-ip-address $PrivateIpAddress2 \
            --output table
        echo "Created NIC $nic with public IP..."
      else
        allnics="$allnics ""$nic"
        az network nic create \
            --resource-group $grpname \
            --location $location \
	    --accelerated-networking true \
            --name $nic \
            --vnet-name $vnet \
            --subnet ${subnet_names[$i]} \
            --output table
        echo "Created NIC $nic..."
    fi
    let "i+=1"
done
let "cli_cnt+=2"
cli_list="$cli_list az network nic create\n az network public-ip create\n"

#
# Add routes to route tables
#
echo "Adding routes to routing tables"

#ip=`az network nic show -g $grpname --name $vmname-vfp-nic|grep privateIpAddress\"|awk '{print $2}'|sed -e  s/\"//g -e s/\,//`
#az network route-table route create -g $grpname --route-table-name $grpname-rt-to-subnet3 --next-hop-type VirtualAppliance --name ToSubnet3 --next-hop-ip-address $ip --address-prefix ${subnet_prefixes[3]} --output table
ip=`az network nic show -g $grpname --name $vmname-vcp-nic|grep privateIpAddress\"|awk '{print $2}'|sed -e  s/\"//g -e s/\,//`
let "cli_cnt+=1"
cli_list="$cli_list az network nic show\n"
az network route-table route create -g $grpname --route-table-name $grpname-rt-to-subnet2 --next-hop-type VirtualAppliance --name ToSubnet2 --next-hop-ip-address $ip --address-prefix ${subnet_prefixes[1]}  --output table
let "cli_cnt+=1"
cli_list="$cli_list az network route-table route create\n"

#
# Create vMX VM
#
echo "Creating vMX VM..."

az vm create \
    --name $vmname \
    --size "Standard_D2s_v3" \
    --image $vmximagename \
    --nics $allnics \
    --resource-group $grpname \
    --location $location \
    --authentication-type ssh \
    --admin-username $admin \
    --generate-ssh-keys \
    --storage-sku Standard_LRS  \
    --boot-diagnostics-storage ${grpname}stor \
    --public-ip-sku Standard \
    --output table
echo "vMX deployment complete"
let "cli_cnt+=1"
cli_list="$cli_list az vm create\n"

echo " List all the resources created in resource group $grpname"

echo "Configure default group= $grpname"
az configure --defaults group=$grpname
az configure --defaults location=$location
let "cli_cnt+=1"
cli_list="$cli_list az configure\n"


echo "Storage Account list & show"
echo "***************************"
for aclist in $(az storage account list --query "[].{name:name}" -o tsv); do
    az storage account show -n $aclist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az storage account list\n az storage account show\n"

echo "Storage Container list"
echo "***************************"
for astorage in $( az storage container list --account-name $storageacc --account-key $KEY1 --query "[].{name:name}" -o tsv ); do
    az storage container show -n $astorage --account-name $storageacc --account-key $KEY1 -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az storage container list\n az storage containter show\n"

echo "Network vnet list & show"
echo "***************************"
for vnlist in $( az network vnet list --query "[].{name:name}" -o tsv); do
    az network vnet show -n $vnlist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az network vnet list\n az network vnet show\n"

echo "Network vnet list-available-ips"
echo "***************************"
az network vnet list-available-ips -n $vnet -o table
let "cli_cnt+=1"
cli_list="$cli_list az network vnet list-available-ips\n"
    

echo "Network vnet list-endpoint-services"
echo "***************************"
az network vnet list-endpoint-services -l $location -o table
let "cli_cnt+=1"
cli_list="$cli_list az network vnet list-endpoint-services\n"

echo "Network subnet list & show"
echo "***************************"
for sublist in $(az network vnet subnet list --vnet-name $vnet --query "[].{name:name}" -o tsv); do
    az network vnet subnet show --vnet-name $vnet -n $sublist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az network vnet subnet list\n az network vnet subnet show\n"

echo "Network subnet list-available-delegations"
echo "***************************"
az network vnet subnet list-available-delegations -l $location -o table
let "cli_cnt+=1"
cli_list="$cli_list az network vnet subnet list-available-delegations\n"

echo "Network route-table list & show"
echo "***************************"
for rlist in $(az network route-table list --query "[].{name:name}" -o tsv); do
    az network route-table show -n $rlist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az network route-table list\n az network route-table show\n"

echo "Network public-ip list & show"
echo "***************************"
for iplist in $(az network public-ip list --query "[].{name:name}" -o tsv); do
    az network public-ip show -n $iplist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az network public-ip list\n az network public-ip show\n"

echo "Network nic list & show"
echo "***************************"
for nlist in $(az network nic list --query "[].{name:name}" -o tsv); do
    az network nic show -n $nlist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az network nic list\n az network nic show\n"

echo "Network Security Group list & show"
echo "*********************************"
for nsglist in $(az network nsg list --query "[].{name:name}" -o tsv); do
    az network nsg show -n $nsglist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az network nsg list\n az network nsg show\n"

echo "Compute Disk list & Show"
echo "*********************************"
for dlist in $(az disk list --query "[].{name:name}" -o tsv); do
    az disk show -n $dlist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az disk list\n az disk show\n"

echo "Virtual Machine list & Show"
echo "***************************"
for vmlist in $(az vm list --query "[].{name:name}" -o tsv); do
    az vm show -n $vmlist -o table
done
let "cli_cnt+=2"
cli_list="$cli_list az vm list\n az vm show\n"

echo "Configure default group= $grpname"
az configure --defaults group=$grpname

echo "List all resources for resource group $grpname"
echo "*************************************************************"

az resource list -o table
let "cli_cnt+=1"
cli_list="$cli_list az resource list\n"

echo " Delete all the resources created in resource group $grpname "
echo "*************************************************************"
for vmlist in $(az vm list --query "[].{name:name}" -o tsv); do
    echo "Delete VM $vmlist "
    echo "***************** "
    az vm delete -n $vmlist --force-deletion yes --yes -y
done
let "cli_cnt+=1"
cli_list="$cli_list az vm delete\n"

for nlist in $(az network nic list --query "[].{name:name}" -o tsv); do
    echo "Delete Network nic $nlist"
    echo "***************************"
    az network nic delete -n $nlist
done
let "cli_cnt+=1"
cli_list="$cli_list az network nic delete\n"

for iplist in $(az network public-ip list --query "[].{name:name}" -o tsv); do
    echo "Delete Network public-ip $iplist"
    echo "***************************"
    az network public-ip delete -n $iplist
done
let "cli_cnt+=1"
cli_list="$cli_list az network public-ip delete\n"

for sublist in $(az network vnet subnet list --vnet-name $vnet --query "[].{name:name}" -o tsv); do
    echo "Delete Network subnet $sublist"
    echo "***************************"
    az network vnet subnet delete --vnet-name $vnet -n $sublist
done
let "cli_cnt+=1"
cli_list="$cli_list az network vnet subnet delete\n"

for vnlist in $( az network vnet list --query "[].{name:name}" -o tsv); do
    echo "Delete Network vnet $vnlist"
    echo "***************************"
    az network vnet delete -n $vnlist
done
let "cli_cnt+=1"
cli_list="$cli_list az network vnet delete\n"

for rlist in $(az network route-table list --query "[].{name:name}" -o tsv); do
    echo "Delete Network route-table $rlist"
    echo "***************************"
    az network route-table delete -n $rlist
done
let "cli_cnt+=1"
cli_list="$cli_list az network route-table delete\n"

for astorage in $( az storage container list --account-name $storageacc --account-key $KEY1 --query "[].{name:name}" -o tsv ); do
    echo "Delete storage container $astorage"
    echo "***************************"
    az storage container delete -n $astorage --account-name $storageacc --account-key $KEY1
done
let "cli_cnt+=1"
cli_list="$cli_list az storage container delete\n"

for aclist in $(az storage account list --query "[].{name:name}" -o tsv); do
    echo "Delete storage account $aclist"
    echo "***************************"
    az storage account delete -n $aclist --yes -y
done
let "cli_cnt+=1"
cli_list="$cli_list az storage account delete\n"

for nsglist in $(az network nsg list --query "[].{name:name}" -o tsv); do
    echo "Delete Network Security Group $nsglist"
    echo "*********************************"
    az network nsg delete -n $nsglist
done
let "cli_cnt+=1"
cli_list="$cli_list az network nsg delete\n"

#for dlist in $(az disk list --query "[].{name:name}" -o tsv); do
#    echo "Delete Compute Disk $dlist "
#    echo "*********************************"
#    az disk revoke-access -n $dlist
#    az disk delete -n $dlist --yes -y
#done

echo "List all resources for resource group $grpname"
echo "*************************************************************"

az resource list -o table || true

fail_cnt=$(( $total_cli - $cli_cnt ))
echo "*****Azure Network cli $total_cli tests run, $cli_cnt passed and $fail_cnt failed*****"
echo "**************************************************************************************"
echo -e "$cli_list"
echo "**************************************************************************************"
