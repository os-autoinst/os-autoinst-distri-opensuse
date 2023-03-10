#!/bin/bash -u
set -o pipefail
. $(dirname "${BASH_SOURCE[0]}")/azure_lib_fn.sh
#set -x
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
account="${6:-azurerd}"

# Variable block
#account="Azure RD"
admin="azureuser"
stor="st"
cont="ct"
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
echo "**Start of AZURE CLI Virtual Network test**"
echo "*******************************************"


# Resource creation
echo "Set Azure Account { az account set }"
cmd_status "az_account_set" az account set -s "$account"

echo "Azure account set to $account"

echo "Creating resource group { az group create }"
cmd_status "az_group_create" az group create -n "$grpname" -l "$location" -o table
echo "Created group $grpname in location $location"

echo "Creating storage account { az storage account create }"
# Create storage account
cmd_status "az_storage_account_create" az storage account create --sku Standard_LRS --location "$location" --kind Storage --resource-group "$grpname" --name "$storageacc" --output table
echo "Created storage account $storageacc"

# Get connection string for the storage account 
echo "Get Connection string for storage account { az storage account keys list }"
cmd_status "az_storage_account_keys_list" az storage account keys list --account-name "$storageacc" --resource-group "$grpname"
KEY1=$(az storage account keys list --account-name $storageacc --resource-group $grpname  | grep -m 1 \"value\": | awk '{print $2}')

# Create storage container
echo "Create storage container { az storage container create }"
cmd_status "az_storage_container_create" az storage container create --account-name "$storageacc" --name "$STORAGE_CONT" --account-key "$KEY1" -o table
echo "Created container $STORAGE_CONT"

count=$(( $number_of_nics - 1 ))
while [ $count -ge 0 ]
do
    subnet_names[$count]=$base_subnet"$count"
    nic_names[$count]=$base_nic"$count"
    count=$(( $count - 1 ))
done

skip=1
echo "Check vnet exists for $grpname and $vnet { az network vnet show }"
az network vnet show -g $grpname  --name  $vnet > /dev/null 2>&1 && skip=2;echo "Vnet \"$vnet\" already exists, skipping vnet and subnet creation"|| skip=1
cmd_status "az_network_vnet_show" az network vnet show -g "$grpname"  --name "$vnet"
echo "Skip value $skip"
if [ $skip -eq 1 ]; then
    # Create VNET
    echo "Creating Azure virtual network $vnet { az network vnet create } "
    az network vnet create \
        --resource-group $grpname \
        --name $vnet \
        --address-prefix $addressprefix \
        --location $location \
        --output table

    echo "Done creating Azure virtual network $vnet"

    # Create as many subnets as there are NICs
    i=0
    echo "subnetprefix" ${subnet_prefixes[@]}
    for prefix in "${subnet_prefixes[@]}"
    do
        echo "Creating virtual subnet ${subnet_names[$i]} $prefix..{az network vnet subnet create }"
        cmd_status "az_network_vnet_subnet_create" az network vnet subnet create \
            --address-prefix "$prefix" \
            --name "${subnet_names[$i]}" \
            --resource-group "$grpname" \
            --vnet-name "$vnet" \
            --output table
        echo "Done creating subnet ${subnet_names[$i]} with prefix $prefix and $i"
	let "i+=1"
    done
fi

#
# Creating routing tables for vMX WAN ports (add tables as needed for more than 2 wan ports)
#
echo "Creating routing tables.{ az network route-table create }"
cmd_status "az_network_route_table_create1" az network route-table create \
    --name "$grpname-rt-to-subnet2" \
    --resource-group "$grpname" \
    --location "$location" \
    --output table
cmd_status "az_network_route_table_create2" az network route-table create \
    --name "$grpname-rt-to-subnet3" \
    --resource-group "$grpname" \
    --location "$location" \
    --output table

echo "Subnet update.{ az network vnet subnet update }"
cmd_status "az_network_vnet_subnet_update1" az network vnet subnet update \
    --resource-group "$grpname" \
    --vnet-name "$vnet" \
    --name "$vnet-vsubnet0" \
    --route-table "$grpname-rt-to-subnet3" \
    --output table
cmd_status "az_network_vnet_subnet_update2" az network vnet subnet update \
     --resource-group "$grpname" \
     --vnet-name "$vnet" \
     --name "$vnet-vsubnet1" \
     --route-table "$grpname-rt-to-subnet2" \
     --output table

#
# Create all NICs
#

echo "Creating public IP addresses and NICs.{ az network public-ip create } { az network nic create }"

i=0
allnics=""
for nic in "${nic_names[@]}"
do
    if [ $i -eq 0 ]; then
        # Create Public IP for first NIC:
        ip=$vmname-vfp-public-ip
        cmd_status "az_network_public-ip_create1" az network public-ip create \
            --name "$ip" \
            --allocation-method Static \
            --resource-group "$grpname" \
            --location "$location" \
            --output table

        # Create 1st NIC
	nic=$vmname-vfp-nic
        allnics="$allnics ""$nic"
        cmd_status "az_network_nic_create1" az network nic create \
            --resource-group "$grpname" \
            --location "$location" \
            --name "$nic" \
            --vnet-name "$vnet" \
            --subnet "${subnet_names[$i]}" \
            --public-ip-address "$ip" \
            --private-ip-address "$PrivateIpAddress" \
            --output table
        echo "Created NIC $nic with public IP..."

    elif [ $i -eq 1 ]; then
        # Create Public IP for first NIC:
        ip2=$vmname-vcp-public-ip
        cmd_status "az_network_public-ip_create2" az network public-ip create \
            --name "$ip2" \
            --allocation-method Static \
            --resource-group "$grpname" \
            --location "$location" \
            --output table

        # Create 2nd NIC
	nic=$vmname-vcp-nic
        allnics="$allnics ""$nic"
        cmd_status "az_network_nic_create2" az network nic create \
            --resource-group "$grpname" \
            --location "$location" \
            --name "$nic" \
            --vnet-name "$vnet" \
            --subnet "${subnet_names[$i]}" \
            --public-ip-address "$ip2" \
            --private-ip-address "$PrivateIpAddress2" \
            --output table
        echo "Created NIC $nic with public IP..."
      else
        allnics="$allnics ""$nic"
        cmd_status "az_network_nic_create" az network nic create \
            --resource-group "$grpname" \
            --location "$location" \
	    --accelerated-networking true \
            --name "$nic" \
            --vnet-name "$vnet" \
            --subnet "${subnet_names[$i]}" \
            --output table
        echo "Created NIC $nic..."
    fi
    let "i+=1"
done

#
# Add routes to route tables
#
echo "Adding routes to routing tables { az network route-table route create }"

#ip=`az network nic show -g $grpname --name $vmname-vfp-nic|grep privateIPAddress\"|awk '{print $2}'|sed -e  s/\"//g -e s/\,//`
#az network route-table route create -g $grpname --route-table-name $grpname-rt-to-subnet3 --next-hop-type VirtualAppliance --name ToSubnet3 --next-hop-ip-address $ip --address-prefix ${subnet_prefixes[3]} --output table
cmd_status "az_network_nic_show" az network nic show -g "$grpname" --name "$vmname-vcp-nic"
ip=$(az network nic show -g $grpname --name $vmname-vcp-nic|grep privateIpAddress\"|awk '{print $2}'|sed -e  s/\"//g -e s/\,//)
echo ${subnet_prefixes[1]} 
cmd_status "az_network_route-table_route_create" az network route-table route create \
    --resource-group "$grpname" \
    --route-table-name "$grpname-rt-to-subnet2" \
    --next-hop-type VirtualAppliance \
    --name ToSubnet2 \
    --next-hop-ip-address "$ip" \
    --address-prefix "${subnet_prefixes[1]}" \
    --output table

#
# Create vMX VM
#
echo "Creating vMX VM..{ az vm create }."
cmd_status "az_vm_create" echo "creating vm "
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
echo " List all the resources created in resource group $grpname { az configure --defaults } "

echo "Configure default group= $grpname"
cmd_status "az_configure1" az configure --defaults group="$grpname"
cmd_status "az_configure2" az configure --defaults location="$location"

echo "Storage Account list & show { az storage account list } { az storage account show }"
echo "***********************************************************************************"
cmd_status "az_storage_account_list" az storage account list
for aclist in $(az storage account list --query "[].{name:name}" -o tsv); do
    cmd_status "az_storage_account_show" az storage account show -n "$aclist" -o table
done

echo "Storage Container list { az storage container list } { az storage containter show }"
echo "***********************************************************************************"
cmd_status "az_storage_container_list" az storage container list --account-name "$storageacc" --account-key "$KEY1"
for astorage in $(az storage container list --account-name $storageacc --account-key $KEY1 --query "[].{name:name}" -o tsv ); do
    cmd_status "az_storage_container_show" az storage container show -n "$astorage" --account-name "$storageacc" --account-key "$KEY1" -o table
done

echo "Network vnet list & show { az network vnet list } { az network vnet show }"
echo "**************************************************************************"
cmd_status "az_network_vnet_list" az network vnet list
for vnlist in $(az network vnet list --query "[].{name:name}" -o tsv); do
    cmd_status "az_network_vnet_show" az network vnet show -n "$vnlist" -o table
done

echo "Network vnet list-available-ips { az network vnet list-available-ips }"
echo "**********************************************************************"
cmd_status "az_network_vnet_list-available-ips" az network vnet list-available-ips -n "$vnet" -o table
    

echo "Network vnet list-endpoint-services { az network vnet list-endpoint-services }"
echo "******************************************************************************"
cmd_status "az_network_vnet_list-endpoint-services" az network vnet list-endpoint-services -l "$location" -o table

echo "Network subnet list & show { az network vnet subnet list } { az network vnet subnet show }"
echo "******************************************************************************************"
cmd_status "az_network_vnet_subnet_list" az network vnet subnet list --vnet-name "$vnet" -o table
for sublist in $(az network vnet subnet list --vnet-name $vnet --query "[].{name:name}" -o tsv); do
    cmd_status "az_network_vnet_subnet_show" az network vnet subnet show --vnet-name "$vnet" -n "$sublist" -o table
done

echo "Network subnet list-available-delegations { az network vnet subnet list-available-delegations }"
echo "***********************************************************************************************"
cmd_status "az_network_vnet_subnet_list-available-delegations" az network vnet subnet list-available-delegations -l "$location" -o table

echo "Network route-table list & show { az network route-table list } { az network route-table show }"
echo "*********************************************************************************************"
cmd_status "az_network_route-table_list" az network route-table list
for rlist in $(az network route-table list --query "[].{name:name}" -o tsv); do
    cmd_status "az_network_route-table_show" az network route-table show -n "$rlist" -o table
done

echo "Network public-ip list & show { az network public-ip list } { az network public-ip show }"
echo "*****************************************************************************************"
cmd_status "az_network_public-ip_list" az network public-ip list
for iplist in $(az network public-ip list --query "[].{name:name}" -o tsv); do
    cmd_status "az_network_public-ip_show" az network public-ip show -n "$iplist" -o table
done

echo "Network nic list & show { az network nic list } { az network nic show }"
echo "***********************************************************************"
cmd_status "az_network_nic_list" az network nic list
for nlist in $(az network nic list --query "[].{name:name}" -o tsv); do
    cmd_status "az_network_nic_show" az network nic show -n "$nlist" -o table
done

echo "Network Security Group list & show { az network nsg list } { az network nsg show }"
echo "*********************************"
cmd_status "az_network_nsg_list" az network nsg list
for nsglist in $(az network nsg list --query "[].{name:name}" -o tsv); do
    cmd_status "az_network_nsg_show" az network nsg show -n "$nsglist" -o table
done

echo "Compute Disk list & { Show az disk list } { az disk show }"
echo "*********************************"
cmd_status "az_disk_list" az disk list
for dlist in $(az disk list --query "[].{name:name}" -o tsv); do
    cmd_status "az_disk_show" az disk show -n "$dlist" -o table
done

echo "Virtual Machine list & Show { az vm list } { az vm show }"
echo "*********************************************************"
cmd_status "az_vm_list" az vm list
for vmlist in $(az vm list --query "[].{name:name}" -o tsv); do
    cmd_status "az_vm_show" az vm show -n "$vmlist" -o table
done

echo "Configure default group= $grpname { az configure --defaults }"
cmd_status "az_configure_defaults_group" az configure --defaults group="$grpname"

echo "List all resources for resource group $grpname { az resource list }"
echo "*******************************************************************"

cmd_status "az_resource_list" az resource list -o table

echo "Delete all the resources created in resource group $grpname { az vm delete } "
echo "******************************************************************************"
cmd_status "az_vm_list" az vm list
for vmlist in $(az vm list --query "[].{name:name}" -o tsv); do
    echo "Delete VM $vmlist "
    echo "***************** "
    cmd_status "az_vm_delete" az vm delete -n "$vmlist" --force-deletion yes --yes -y
done

cmd_status "az_network_nic_list" az network nic list
for nlist in $(az network nic list --query "[].{name:name}" -o tsv); do
    echo "Delete Network nic $nlist { az network nic delete }"
    echo "***************************************************"
    cmd_status "az_network_nic_delete" az network nic delete -n "$nlist"
done

cmd_status "az_network_public-ip_list" az network public-ip list
for iplist in $(az network public-ip list --query "[].{name:name}" -o tsv); do
    echo "Delete Network public-ip $iplist { az network public-ip delete } "
    echo "*****************************************************************"
    cmd_status "az_network_public-ip_delete" az network public-ip delete -n "$iplist"
done

cmd_status "az_network_vnet_subnet_list" az network vnet subnet list --vnet-name "$vnet"
for sublist in $(az network vnet subnet list --vnet-name "$vnet" --query "[].{name:name}" -o tsv); do
    echo "Delete Network subnet $sublist { az network vnet subnet delete }"
    echo "****************************************************************"
    cmd_status "az_network_vnet_subnet_delete" az network vnet subnet delete --vnet-name "$vnet" -n "$sublist"
done

cmd_status "az_network_vnet_list" az network vnet list
for vnlist in $(az network vnet list --query "[].{name:name}" -o tsv); do
    echo "Delete Network vnet $vnlist { az network vnet delete } "
    echo "*******************************************************"
    cmd_status "az_network_vnet_delete" az network vnet delete -n "$vnlist"
done

cmd_status "az_network_route-table_list" az network route-table list
for rlist in $(az network route-table list --query "[].{name:name}" -o tsv); do
    echo "Delete Network route-table $rlist { az network route-table delete }"
    echo "*******************************************************************"
    cmd_status "az_network_route-table_delete" az network route-table delete -n $rlist
done

cmd_status "az_storage_container_list" az storage container list --account-name "$storageacc" --account-key "$KEY1" 
for astorage in $(az storage container list --account-name $storageacc --account-key $KEY1 --query "[].{name:name}" -o tsv ); do
    echo "Delete storage container $astorage { az storage container delete } "
    echo "*******************************************************************"
    cmd_status "az_storage_container_delete" az storage container delete -n "$astorage" --account-name "$storageacc" --account-key "$KEY1"
done

cmd_status "az_storage_account_list" az storage account list
for aclist in $(az storage account list --query "[].{name:name}" -o tsv); do
    echo "Delete storage account $aclist { az storage account delete } "
    echo "*************************************************************"
    cmd_status "az_storage_account_delete" az storage account delete -n "$aclist" --yes -y
done

cmd_status "az_network_nsg_list" az network nsg list
for nsglist in $(az network nsg list --query "[].{name:name}" -o tsv); do
    echo "Delete Network Security Group $nsglist { az network nsg delete } "
    echo "*****************************************************************"
    cmd_status "az_network_nsg_delete" az network nsg delete -n "$nsglist"
done

#for dlist in $(cmd_status "az_disk_list" az disk list --query "[].{name:name}" -o tsv); do
#    echo "Delete Compute Disk $dlist "
#    echo "*********************************"
#    cmd_status "az_disk_revoke-access" az disk revoke-access -n "$dlist"
#    cmd_status "az_disk_delete" az disk delete -n "$dlist" --yes -y
#done

echo "List all resources for resource group $grpname { az resource list }"
echo "*******************************************************************"
cmd_status "az_resource_list" az resource list -o table

echo "              Virtual Network AZURE CLI Test Report                "
echo "*******************************************************************"
final_exit
