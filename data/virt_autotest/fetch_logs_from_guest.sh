#!/bin/bash -x

#Setup libguestfs environmen for non-x86_64 machine
function setup_libguestfs_env() {
        local host_arch=`uname -p`
        if [[ ${host_arch} != "x86_64" ]];then
           export SUPERMIN_KERNEL_VERSION=`uname -r`
           if [[ -f "/boot/Image-${SUPERMIN_KERNEL_VERSION}" ]];then
              export SUPERMIN_KERNEL="/boot/Image-${SUPERMIN_KERNEL_VERSION}"
           else
              export SUPERMIN_KERNEL="/boot/image-${SUPERMIN_KERNEL_VERSION}"
           fi
           export SUPERMIN_MODULES="/lib/modules/${SUPERMIN_KERNEL_VERSION}"
        fi
        return 0
}

#Find the correct disk device that holds the specific folder which contains log filesystem
function find_disk_hosts_filesystem() { 
        local guest_domain=$1
        local guest_filesystem=$2
        guest_filesystem=${guest_filesystem/\//}
        guest_filesystem=${guest_filesystem/\/*/}

        local guest_devices=`virt-filesystems -d ${guest_domain} | grep -ioE "^/dev.*[^@].*$"`
        local guest_device=""
        local onedevice=""
        for onedevice in ${guest_devices[@]};do
            (guestfish -r -d ${guest_domain} -m ${onedevice} ls / | grep -ioE "^${guest_filesystem}$") &> /dev/null
            if [[ $? -eq 0 ]];then
               guest_device=${onedevice}
               break
            else
               continue
            fi
        done

        if [[ ${guest_device} != "" ]];then
           echo ${guest_device}
        else
           echo "Can not find disk device that hosts ${guest_filesystem}."
        fi
}

#Fetach logs from virtual machine to local host via ssh
function fetch_logs_from_guest_via_ssh() {
        local guest_domain=$1
        local guest_ipaddr=$2
        local logs_folder=$3
        local guest_user="root"
        local guest_pass="novell"
        local sshpass_scp_cmd="sshpass -p ${guest_pass} scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r ${guest_user}@${guest_ipaddr}"
        local sshpass_ssh_cmd="sshpass -p ${guest_pass} ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${guest_user}@${guest_ipaddr}"
        local guest_transformed=${guest_domain//./_}

        local ret_result=128
        local retry_times=0
        while [[ ${retry_times} -lt 2 ]] && [[ ${ret_result} -ne 0 ]];
        do
              mkdir -p ${logs_folder}/${guest_transformed}
              echo -e "${sshpass_scp_cmd}:${logs_folder} ${logs_folder}/${guest_transformed}"
              ${sshpass_scp_cmd}:${logs_folder} ${logs_folder}/${guest_transformed}
              ret_result=$?
              if [[ ${ret_result} -eq 0 ]];then
                 echo -e "Successfully fetched ${logs_folder} from guest ${guest_domain} via ssh."
                 ${sshpass_ssh_cmd} rm -f -r ${logs_folder}          
                 break          
              fi
              retry_times=$((${retry_times}+1))
        done

        if [[ ${ret_result} -ne 0 ]];then
            echo -e "Failed to fetch ${logs_folder} from guest ${guest_domain} via ssh."
        fi

	return ${ret_result}
}

#Fetch logs from virtual machine to local host by using libguestfs tools
function fetch_logs_from_guest_via_libguestfs() {
        local guest_domain=$1
        local logs_fetched=$2
        local logs_folder=$3

        setup_libguestfs_env
        virt-filesystems -d ${guest_domain} &> /dev/null
        if [[ $? -ne 0 ]];then
           echo -e "Running ${guest_domain} can not be accessed by libguestfs currently. Shut it down now."
           virsh destroy ${guest_domain}
        fi
        local guest_device=`find_disk_hosts_filesystem ${guest_domain} ${logs_fetched}`
        echo -e "${guest_domain} ${guest_device} contains ${logs_fetched}."
        local guest_transformed=${guest_domain//./_}
        mkdir -p ${logs_folder}/${guest_transformed}
        echo -e "guestfish -r -d ${guest_domain} -m ${guest_device} copy-out ${logs_fetched} ${logs_folder}/${guest_transformed}"
        guestfish -r -d ${guest_domain} -m ${guest_device} copy-out ${logs_fetched} ${logs_folder}/${guest_transformed}
        if [[ $? -eq 0 ]];then
           echo -e "Copied out ${logs_fetched} from ${guest_domain} successfully."
           return 0
        else
           echo -e "Try again to mount ${guest_device}:/:subvol=@ with guestfish."
           echo -e "guestfish -r -d ${guest_domain} -m ${guest_device}:/:subvol=@ copy-out ${logs_fetched} ${logs_folder}/${guest_transformed}"
           guestfish -r -d ${guest_domain} -m ${guest_device}:/:subvol=@ copy-out ${logs_fetched} ${logs_folder}/${guest_transformed}
           if [[ $? -eq 0 ]];then
              echo -e "Copied out ${logs_fetched} from ${guest_domain} successfully."
              return 0
           else
              echo -e "Failed to copy out ${logs_fetched} from ${guest_domain}."
              return 1
           fi
        fi
}

#Power off virtual machine if necessary and remove logs folder in it by using libguestfs
function remove_logs_folder_from_guest_via_libguestfs() {
        local guest_domain=$1
        local logs_folder=$2
        local ret_result=0

        echo -e "Going to remove ${logs_folder} from ${guest_domain} via libguestfs"
        local guest_device=`find_disk_hosts_filesystem ${guest_domain} ${logs_folder}`
        echo -e "guestfish -w -d ${guest_domain} -m ${guest_device} rm-rf ${logs_folder}"
        guestfish -w -d ${guest_domain} -m ${guest_device} rm-rf ${logs_folder}
        ret_result=$?
        if [[ ${ret_result} -ne 0 ]];then
	   echo -e "Power off ${guest_domain} to make read-write access possible via libguestfs."
           virsh destroy ${guest_domain}
           echo -e "guestfish -w -d ${guest_domain} -m ${guest_device} rm-rf ${logs_folder}"
           guestfish -w -d ${guest_domain} -m ${guest_device} rm-rf ${logs_folder}
           ret_result=$?
           if [[ ${ret_result} -ne 0 ]];then
              echo -e "Try again to mount ${guest_device}:/:subvol=@ with guestfish."
              echo -e "guestfish -w -d ${guest_domain} -m ${guest_device}:/:subvol=@ rm-rf ${logs_folder}"
              guestfish -w -d ${guest_domain} -m ${guest_device}:/:subvol=@ rm-rf ${logs_folder}
              ret_result=$?
           fi
        fi

        virsh start ${guest_domain}
        return ${ret_result}
}

#Fetch logs from virtual machine to local host via ssh firstly. Will resort to libguestfs tools if ssh connection is broken
function fetch_logs_from_guest() {
	local guest_domain=$1
	local guest_ipaddr=$2
	local logs_folder=$3
	shift
	shift
	shift
	local extra_logs=($@)

	local ret1=0
	fetch_logs_from_guest_via_ssh ${guest_domain} ${guest_ipaddr} ${logs_folder}
	if [[ $? -ne 0 ]];then
	   echo -e "Try to use libguestfs tools to fetch ${logs_folder} from ${guest_domain}."
	   fetch_logs_from_guest_via_libguestfs ${guest_domain} ${logs_folder} ${logs_folder}
	   ret1=$?
	   if [[ ${ret1} -eq 0 ]];then
	      remove_logs_folder_from_guest_via_libguestfs ${guest_domain} ${logs_folder}	
	      if [[ $? -eq 0 ]];then
	         echo -e "Successfully removed ${logs_folder} from ${guest_domain} via libguestfs."
	      else
	         echo -e "Failed to remove ${logs_folder} from ${guest_domain} via libguestfs. Not fatal error."
	      fi
	   fi
	fi

	local ret2=0
	if [[ ${extra_logs[@]} != "" && ${ret1} -ne 0 ]];then
	   echo -e "Try to use libguestfs tools to fetch ${extra_logs[@]} from ${guest_domain}."
	   local eachlog=""
	   for eachlog in ${extra_logs[@]};do
	       fetch_logs_from_guest_via_libguestfs ${guest_domain} ${eachlog} ${logs_folder}
	       ret2=$(( ${ret2} | $? ))
	   done           
	   if [[ ${ret2} -eq 0 ]];then
	      echo -e "Copied out ${extra_logs[@]} from ${guest_domain} successfully."
	   else
	      echo -e "Failed to copy out ${extra_logs[@]} from ${guest_domain}."
	   fi
	fi 

	virsh start ${guest_domain} 
	if [[ ${ret1} -eq 0 && ${ret2} -eq 0 ]];then
	   return 0
	else
	   return 1
	fi
}

#Compress logs folder on local host which contains all logs from host and guest
function compress_virt_logs_folder() {
	local logs_folder=$1
	local logs_root=${logs_folder/\//}
	logs_root=${logs_root/\/*/}

	pushd ${logs_folder}
	local mycmd="tar -czvf /${logs_root}/virt_logs_all.tar.gz *"
	echo -e "$mycmd"
	$mycmd
	if [[ $? -eq 0 ]];then
	   echo -e "Successfully compressed ${logs_folder} to /${logs_root}/virt_logs_all.tar.gz"
	   popd
	   return 0
	else
	   echo -e "Failed to ${logs_folder} to /${logs_root}/virt_logs_all.tar.gz"
	   popd
	   return 1
	fi
}

#Usage and help info for the script
help_usage(){
	echo "script usage: $(basename $0) [-f \"Logs folder which contains logs collected(Can be omitted/Default to /tmp/virt_logs_residence)\"] \
[-g \"guests to be involved, for example, \"guest1 guest2 guest3\" or all or none(Can be omitted/Default to all)\"] \
[-e \"Extra folders or files to be fetched from guest, for example, \"log_file1 log_file2 log_folder1\"(Can be omitted/Default to nothing)\"] \
[-h help]"
}

fetch_logs_from_guest_log="/var/log/fetch_logs_from_guest.log"
virt_guests_wanted=""
virt_logs_folder=""
virt_extra_logs_guest=""
fetch_logs_from_guest_log_result=0
rm -f -r ${fetch_logs_from_guest_log}

#Parse input arguments, all options are optional
#Any log paremter passed in should take absolute path form
while getopts 'l:g:e:h' OPTION; do
   case "$OPTION" in
      f)
        virt_logs_folder="$OPTARG"
        echo "Logs folder is ${virt_logs_folder}" | tee -a ${fetch_logs_from_guest_log}
        ;;
      g)
        virt_guests_wanted="$OPTARG"
        echo "The guests involved are ${virt_guests_wanted}" | tee -a ${fetch_logs_from_guest_log}
        ;;
      e)
        virt_extra_logs_guest="$OPTARG"
        virt_extra_logs_guest=(${virt_extra_logs_guest})
        echo "The extra guest logs to be fetched are ${virt_extra_logs_guest[@]}" | tee -a ${fetch_logs_from_guest_log}
        ;;
      h)
        help_usage | tee -a ${fetch_logs_from_guest_log}
        exit 1
        ;;
      *)
        help_usage | tee -a ${fetch_logs_from_guest_log}
        exit 1
        ;;
   esac
done
shift "$(($OPTIND -1))"
if [[ ${virt_logs_folder} == "" ]];then
   virt_logs_folder="/tmp/virt_logs_residence"
fi
if [[ ${virt_guests_wanted} == "" ]];then
   virt_guests_wanted="all"
fi

unset guest_hash_ipaddr
declare -a guest_hash_ipaddr=""
guest_domain_types="sles|opensuse|tumbleweed|leap|oracle|alp"
guests_inactive_array=`virsh list --inactive | grep -Ei "${guest_domain_types}" | awk '{print $2}'`
guest_domains_array=`virsh list  --all | grep -Ei "${guest_domain_types}" | awk '{print $2}'`
guest_current=""
guest_macaddresses_array=""
guest_ipaddress="";
guest_hash_index=0
dhcpd_lease_file="/var/lib/dhcp/db/dhcpd.leases"

#Install necessary packages
echo -e "Install necessary packages. zypper install -y sshpass nmap xmlstarlet libguestfs* guestfs-tools" | tee -a ${fetch_logs_from_guest_log}
zypper install -y sshpass nmap xmlstarlet libguestfs* guestfs-tools | tee -a ${fetch_logs_from_guest_log}

#Establish reachable networks and hosts database on host
#In ALP, podman network takes ~40 minutes to finish scan, but it's useless, so exclude it
subnets_in_route=`ip route show all | grep -v cni-podman0 | awk '{print $1}' | grep -v default`
subnets_scan_results=""
subnets_scan_index=0
echo -e "Subnets ${subnets_in_route[@]} are reachable on host judging by ip route show all" | tee -a ${fetch_logs_from_guest_log}
echo -e "Establishing reachable hosts in subnets ${subnets_in_route[@]} database on host" | tee -a ${fetch_logs_from_guest_log}
for single_subnet in ${subnets_in_route[@]};do
    single_subnet_transformed=${single_subnet//./_}
    single_subnet_transformed=${single_subnet_transformed/\//_}
    scan_timestamp=`date "+%F-%H-%M-%S"`
    mkdir -p "${virt_logs_folder}/nmap_subnets_scan_results"
    single_subnet_scan_results=${virt_logs_folder}'/nmap_subnets_scan_results/nmap_scan_'${single_subnet_transformed}'_'${scan_timestamp}
    subnets_scan_results[${subnets_scan_index}]=${single_subnet_scan_results}
    echo -e "nmap -sn $single_subnet -oX $single_subnet_scan_results" | tee -a ${fetch_logs_from_guest_log}
    nmap -T4 -sn $single_subnet -oX $single_subnet_scan_results | tee -a ${fetch_logs_from_guest_log}
    subnets_scan_index=$(( ${subnets_scan_index} + 1 ))
done

#Establish virtual machine domain name and ip address mapping
for guest_current in ${guest_domains_array[@]};do
    guest_macaddresses_array[${guest_hash_index}]=`virsh domiflist --domain ${guest_current} | grep -oE "([0-9|a-z]{2}:){5}[0-9|a-z]{2}"`
    guest_ipaddress=`tac $dhcpd_lease_file | awk '!($0 in S) {print; S[$0]}' | tac | grep -iE "${guest_macaddresses_array[${guest_hash_index}]}" -B8 | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | tail -1`
    if [[ -z ${guest_ipaddress} ]];then
       for single_subnet_scan_results in ${subnets_scan_results[@]};do
           guest_ipaddress=`xmlstarlet sel -t -v //address/@addr -n $single_subnet_scan_results | grep -i ${guest_macaddresses_array[${guest_hash_index}]} -B1 | grep -iv ${guest_macaddresses_array[${guest_hash_index}]}`
           if [[ ! -z ${guest_ipaddress} ]];then
               break
           fi
       done
    fi
    if [[ -z ${guest_ipaddress} ]];then
       guest_ipaddress="NO_IP_ADDRESS_FOUND"
    fi
    guest_hash_ipaddr[${guest_hash_index}]=${guest_ipaddress}
    echo -e ${guest_current}:${guest_hash_ipaddr[${guest_hash_index}]} | tee -a ${fetch_logs_from_guest_log}
    guest_hash_index=$(( ${guest_hash_index} + 1 ))
done

#Start fetching logs from virtual machine
if [[ ${virt_guests_wanted} == "none" ]];then
   echo -e "Will not fetch any log from any guest." | tee -a ${fetch_logs_from_guest_log}
else
   guest_hash_index=0
   for guest_current in ${guest_domains_array[@]};do
       if [[ ${virt_guests_wanted} == "all" ]] || [[ ${virt_guests_wanted} =~ .*${guest_current}.* ]];then
          if [[ ${guests_inactive_array[@]} == .*${guest_current}.* ]];then
             echo -e "Virtual machine ${guest_current} in shutdown state. Skip fetching logs from it." | tee -a ${fetch_logs_from_guest_log}
          else
             echo -e "fetch_logs_from_guest ${guest_current} ${virt_logs_folder}" | tee -a ${fetch_logs_from_guest_log}
             fetch_logs_from_guest ${guest_current} ${guest_hash_ipaddr[${guest_hash_index}]} ${virt_logs_folder} ${virt_extra_logs_guest[@]} | tee -a ${fetch_logs_from_guest_log}
             fetch_logs_from_guest_log_result=$(( ${fetch_logs_from_guest_log_result} | $? ))
          fi
       else
          echo -e "Virtual machine ${guest_current} is not wanted. Skip fetching logs from it." | tee -a ${fetch_logs_from_guest_log}
       fi
       guest_hash_index=$(( ${guest_hash_index} + 1 ))
   done
fi
compress_virt_logs_folder ${virt_logs_folder} | tee -a ${fetch_logs_from_guest_log}
fetch_logs_from_guest_log_result=$(( ${fetch_logs_from_guest_log_result} | $? ))
rm -f -r ${virt_logs_folder}
exit ${fetch_logs_from_guest_log_result}
