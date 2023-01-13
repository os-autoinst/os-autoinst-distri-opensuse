#!/bin/bash -x
set -o pipefail
shopt -s nocasematch

#Obtain SLES release version and service pack level
function get_sles_release() {
        local query_type=$1
        local version_file=$2
        if [[ -z ${version_file} ]];then
           version_file="/etc/os-release"
        fi 
        local sles_version=`cat ${version_file} | grep -i version= | grep -iEo "[0-9]{1,}(\.|\-)?(sp)?([0-9]{1,})?"`
        [[ ${sles_version} =~ ([0-9]*)\.*([0-9]*) ]]
        local sles_release=${BASH_REMATCH[1]}
        local sles_spack=${BASH_REMATCH[2]}
        if [[ -z ${sles_spack} ]];then
           sles_spack=0
        fi

        if [[ ${query_type} == "release" ]];then
           echo ${sles_release}
        elif [[ ${query_type} == "spack" ]];then
           echo ${sles_spack}
        fi
}

#Get host hypervisor type
function get_sles_hypervisor() {
        (lsmod | grep -i kvm || dmesg | grep -i kvm) &> /dev/null
        if [[ $? -eq 0 ]];then
           echo "KVM"
        else
           echo "XEN"
        fi
}

#Setup folder on host to be used as logs warehouse which will hold all host and guest logs at the last
function setup_common_logs_folder() {
        local logs_folder=$1
        mkdir -p ${logs_folder}
        chmod -R 777 ${logs_folder}
        return $?
}

#Collect any desired logs from virtual machine by using virsh console and expect script
function collect_logs_via_guest_console() {
        local guest_domain=$1
        local logs_folder=$2
        shift
        shift
        local extra_logs=$@
        local expfile="${logs_folder}/collect_logs_via_guest_console.exp"
        local guest_transformed=${guest_domain//./_}
        touch ${expfile}
        chmod 777 ${expfile}
        local hypervisor=`get_sles_hypervisor`
cat <<EOF > ${expfile}
#!/usr/bin/expect
set hypervisor [lindex \$argv 0]
set guest_domain [lindex \$argv 1]
set guest_transformed [lindex \$argv 2]
set logs_folder [lindex \$argv 3]
set extra_logs [lindex \$argv 4]
set retry_times 2
set ret_result 1
set fail_string sad_to_fail
set pass_string glad_go_pass

while { \${retry_times} > 0 } {
      if { \${hypervisor} == {KVM} } {
         spawn virsh console --force \${guest_domain}
      }
      if { \${hypervisor} == {XEN} } {
         spawn virsh console \${guest_domain}
      }
      set timeout 60
      expect  {
         -nocase "escape character" {send "\r\r"; exp_continue -continue_timer}
         -nocase "password:" {send "\r"}
         -re "( |\\\])#" {send "exit\r"}
         -nocase "mistake|wrong|fault|error|fail|exception|not*found|timed*out" {puts "Can not establish virsh console to \${guest_domain}\r"; set ret_result 1}
      }
      expect {
         -nocase "login: $"  {send "root\r"; set ret_result 0; exp_continue -continue_timer}
         -nocase "password:" {send "novell\rcd ~\r"; exp_continue -continue_timer}
         -nocase "mistake|wrong|fault|error|fail|exception|not*found|timed*out" {puts "Can not login virsh console to \${guest_domain}\r"; set ret_result 1}
      }

      if { \${ret_result} == 0 } {
         set timeout 1200
         expect -re "~( |\\\])#"
         send "mkdir -p \${logs_folder};export time_stamp=\`date \'+%Y%m%d%H%M%S\'\`\r"
         expect -re "~( |\\\])#"
         if { \${extra_logs} == {support_config} } {
            send "rm -f -r \${logs_folder}/*supportconfig*\r"
            send "supportconfig -y -A -o AUDIT -t \${logs_folder} -B guest_\${guest_transformed}_supportconfig_\\\${time_stamp}\r"
         }
         if { \${extra_logs} == {sos_report} } {
            send "rm -f -r \${logs_folder}/*sosreport*\r"
            send "sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir \${logs_folder}\r"
         }
         if { \${extra_logs} != {support_config} && \${extra_logs} != {sos_report} && \${extra_logs} != "" } {
            send "rm -f -r \${logs_folder}/*extra_logs*\r"
            send "mkdir -p \${logs_folder}/guest_\${guest_transformed}_extra_logs;cp --parent -r -f \${extra_logs} \${logs_folder}/guest_\${guest_transformed}_extra_logs\r"
         }
         expect {
            -re "~( |\\\])#" {send "export ret=\\\$?;cd /tmp;(if \[\[ \\\$ret -ne 0 ]];then echo \${fail_string};else echo \${pass_string};fi)\r"; exp_continue -continue_timer}
            "sad_to_fail" {puts "Can not collect \${extra_logs} from \${guest_domain}\r"; set ret_result 1;  exp_continue -continue_timer}
            "glad_go_pass" {puts "Finished collecting \${extra_logs} from \${guest_domain}\r"; set ret_result 0;  exp_continue -continue_timer}
            -re "tmp( |\\\])#" {send "cd ~\r"; send "exit\r"}
         }
      }

      if { \${ret_result} == 0 && \${extra_logs} != "" } {
         expect -nocase "login: $" {puts "Successfully collected \${extra_logs} from \${guest_domain}\r"; exit \${ret_result}}
      }

      if { \${ret_result} == 1 && \${extra_logs} != "" } {
         expect -nocase "login: $" {puts "Will try to collect \${extra_logs} from \${guest_domain} again\r"}
      }

      if { \${extra_logs} == "" } {
         expect -nocase "login: $" {puts "Nothing to collect from \${guest_domain}. Please specify something.\r"}
      }

      set retry_times [expr \${retry_times}-1]
      close -i \${spawn_id}
}
exit \${ret_result}
EOF

	echo -e "${expfile} to be executed is as below:"
	cat ${expfile}
 
	local procid=""
	for procid in `ps aux | grep -iE "${expfile}|virsh console" | grep -v "grep" | awk '{print $2}'`;do
	    kill -9 ${procid}
	done
	echo -e "expect ${expfile} "${hypervisor}" "${guest_domain}" "${guest_transformed}" "${logs_folder}" "${extra_logs}""
	expect ${expfile} "${hypervisor}" "${guest_domain}" "${guest_transformed}" "${logs_folder}" "${extra_logs}"
	if [[ $? == 0 ]];then
	   echo -e "${expfile} returned with success. Successfully collected ${extra_logs} via ${guest_domain} console."
	   rm -f ${expfile}
	   return 0
	else
	   echo -e "${expfile} returned with failure. Failed to collect ${extra_logs} via ${guest_domain} console."
	   rm -f ${expfile}
	   return 1
	fi
}

#This function supports collecting supportconfig or sosreport from both host and guest. The argument target_type will be given 'host' or 'guest'
#Will resort to guest virsh console if collecting from guest ssh failed. Collecting logs from host only supports local host
#Typical usage: collect_system_log_and_diagnosis logs_folder host or collect_system_log_and_diagnosis logs_folder guest guest_ip guest_domain_name
function collect_system_log_and_diagnosis() {
	local logs_folder=$1
	local target_type=$2
	local target_ipaddr=$3
	local target_domain=$4
	local target_user=""
	local target_pass=""
	local sshpass_ssh_cmd=""

	if [[ ${target_type} == "guest" ]];then
	   target_user="root"
	   target_pass="novell"
	   sshpass_ssh_cmd="sshpass -p ${target_pass} ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${target_user}@${target_ipaddr}"
	fi	

	if [[ ${target_domain} != "" ]];then
	   local target_transformed=${target_domain//./_}
	else
	   local target_transformed=`hostname`
	   target_transformed=${target_transformed//./_}
	fi

	local ret_result=128
	local retry_times=0
	while [[ ${retry_times} -lt 2 ]] && [[ ${ret_result} -ne 0 ]];
	do
	   if [[ ${target_type} == "host" && `cat /etc/issue` =~ oracle|rhel|red.*hat|fedora ]] || [[ ${target_type} == "guest" && ${target_transformed} =~ oracle|rhel|fedora ]];then
	      ${sshpass_ssh_cmd} rm -f -r ${logs_folder}/*sosreport*
	      echo -e "${sshpass_ssh_cmd} mkdir -p ${logs_folder}"
	      echo -e "${sshpass_ssh_cmd} sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir ${logs_folder}"
	      ${sshpass_ssh_cmd} mkdir -p ${logs_folder}
	      ${sshpass_ssh_cmd} sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir ${logs_folder}
	   else	   
    	      local time_stamp=`date '+%Y%m%d%H%M%S'`
	      ${sshpass_ssh_cmd} rm -f -r ${logs_folder}/*supportconfig*
	      echo -e "${sshpass_ssh_cmd} supportconfig -y -A -o AUDIT -t ${logs_folder} -B ${target_type}_${target_transformed}_supportconfig_${time_stamp}"
	      ${sshpass_ssh_cmd} supportconfig -y -A -o AUDIT -t ${logs_folder} -B ${target_type}_${target_transformed}_supportconfig_${time_stamp}
	   fi
	   ret_result=$?
	   if [[ ${ret_result} -eq 0 ]];then
	      echo -e "Successfully collected supportconfig or sosreport from ${target_type} ${target_domain} via ssh."
	      break
	   fi
	   retry_times=$((${retry_times}+1))
	done

	if [[ ${target_type} == "guest" ]] && [[ ${ret_result} -ne 0 ]];then
	   echo -e "Can not collect supportconfig or sosreport from ${target_type} ${target_domain} via ssh. Try to use guest virsh console."
	   if [[ ${target_domain} =~ oracle|rhel|fedora ]];then
	      echo -e "collect_sosreport_via_guest_console ${target_domain} ${logs_folder}"
	      collect_sosreport_via_guest_console ${target_domain} ${logs_folder}
	   else 
	      echo -e "collect_supportconfig_via_guest_console ${target_domain} ${logs_folder}"
	      collect_supportconfig_via_guest_console ${target_domain} ${logs_folder}
	   fi
	   if [[ $? -eq 0 ]];then
	      return 0
	   else
	      return 1
	   fi
	elif [[ ${target_type} == "host" ]] && [[ ${ret_result} -ne 0 ]];then
	   echo -e "Can not collect supportconfig from ${target_type} ${target_domain} vis ssh. Please investigate."
	   return 1
	fi

	return 0
}

function collect_supportconfig_via_guest_console() {
        local guest_domain=$1
        local logs_folder=$2
        collect_logs_via_guest_console ${guest_domain} ${logs_folder} support_config
        if [[ $? -eq 0 ]];then
           return 0
        else
           return 1
        fi
}

function collect_sosreport_via_guest_console() {
        local guest_domain=$1
        local logs_folder=$2
        collect_logs_via_guest_console ${guest_domain} ${logs_folder} sos_report
        if [[ $? -eq 0 ]];then
           return 0
        else
           return 1
        fi
}

function collect_extra_logs_via_guest_console() {
        local guest_domain=$1
        local logs_folder=$2
        shift
        shift
        local extra_logs=$@
        collect_logs_via_guest_console ${guest_domain} ${logs_folder} ${extra_logs}
        if [[ $? -eq 0 ]];then
           return 0
        else
           return 1
        fi
}

#Collect any extra logs wanted from guest. Will resort to guest virsh console if collecting from ssh failed.
function collect_extra_logs_from_guest() {
        local logs_folder=$1
        local guest_ipaddr=$2
        local guest_domain=$3
        shift
        shift
        shift
        local extra_logs=$@
      
        if [[ ${extra_logs} != "" ]];then
           local guest_user="root"
           local guest_pass="novell"
           local sshpass_ssh_cmd="sshpass -p ${guest_pass} ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${guest_user}@${guest_ipaddr}"
           local guest_transformed=${guest_domain//./_}
           local ret_result=128
           local retry_times=0
           while [[ ${retry_times} -lt 2 ]] && [[ ${ret_result} -ne 0 ]];
           do
                 ${sshpass_ssh_cmd} rm -f -r ${logs_folder}/guest_${guest_transformed}_extra_logs
                 ${sshpass_ssh_cmd} mkdir -p ${logs_folder}/guest_${guest_transformed}_extra_logs
                 echo -e "${sshpass_ssh_cmd} cp --parent -r -f ${extra_logs} ${logs_folder}/guest_${guest_transformed}_extra_logs"
                 ${sshpass_ssh_cmd} cp --parent -r -f ${extra_logs} ${logs_folder}/guest_${guest_transformed}_extra_logs
                 ret_result=$?
                 if [[ ${ret_result} -eq 0 ]];then
                    echo -e "Successfully collected ${extra_logs} from guest ${guest_domain} via ssh."
                    break
                 fi
                 retry_times=$((${retry_times}+1))
           done
           if [[ ${ret_result} -ne 0 ]];then
              echo -e "Can not collect ${extra_logs} from guest ${guest_domain} via ssh. Try to use guest virsh console"
              echo -e "collect_extra_logs_via_guest_console ${guest_domain} ${logs_folder} ${extra_logs}"
              collect_extra_logs_via_guest_console ${guest_domain} ${logs_folder} ${extra_logs}
              if [[ $? -eq 0 ]];then
                 return 0
              else
                 return 1
              fi
           else
              return 0
	   fi
        else
           echo -e "There is no extra logs to be collected. Please specify something."
           return 0
        fi
}

#Collect any extra wanted logs from host. And provide more complete virtualization logs for SLE-11-SP4 ,SLE-12 and SLE-15 hosts.
function collect_extra_logs_from_host() {
	local logs_folder=$1
	local target_domain=$2
	shift
	shift
	local extra_logs=$@
	local ret_result=0

	if [[ ${target_domain} != "" ]];then
	   local target_transformed=${target_domain//./_}
	else
	   local target_transformed=`hostname`
	   target_transformed=${target_transformed//./_}
	fi
	local extra_logs_folder=${logs_folder}/host_${target_transformed}_extra_logs
	mkdir -p ${extra_logs_folder}
	if [[ ${extra_logs} != "" ]];then
	   cp --parent -f -r ${extra_logs} ${extra_logs_folder}
	   ret_result=$?
	   if [[ ${ret_result} -eq 0 ]];then
	      echo -e "Successfully collected extra logs ${extra_logs} from host."
	   else
	      echo -e "Failed to collect extra logs ${extra_logs} from host."
	   fi
	else
	   echo -e "No extra logs to be collected from host. Please specify something."
	fi

	local release=`get_sles_release release`
	local spack=`get_sles_release spack`
	local libvirt_boot_log="/var/lib/libvirt/boot"
	local libvirt_qemu_log="/var/lib/libvirt/qemu"
	local libvirt_log="/var/log/libvirt"
	local libvirtd_log="${libvirt_log}/libvirtd.log"
	local xen_log="/var/log/xen"
	local xen_boot_log="${xen_log}/xen-boot.log"

	if [[ ${release} -lt 12 ]];then
	   cp --parent -f -r ${libvirt_log} ${extra_logs_folder}
	   ret_result=$(( ${ret_result} | $? ))
	   if [[ `get_sles_hypervisor` == "XEN" ]];then
	      cp --parent -f -r ${xen_log} ${extra_logs_folder}
	      ret_result=$(( ${ret_result} | $? ))
	   fi
	elif [[ ${release} -eq 12 ]];then
           cp --parent -f -r ${libvirt_boot_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
           cp --parent -f -r ${libvirt_qemu_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
           cp --parent -f -r ${libvirtd_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
           if [[ `get_sles_hypervisor` == "XEN" ]];then
              cp --parent -f -r ${xen_boot_log} ${extra_logs_folder}
              ret_result=$(( ${ret_result} | $? ))
           fi           
        elif [[ ${release} -eq 15 ]];then
           cp --parent -f -r ${libvirt_boot_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
           cp --parent -f -r ${libvirt_qemu_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
           if [[ `get_sles_hypervisor` == "XEN" ]];then
              cp --parent -f -r ${xen_boot_log} ${extra_logs_folder}
              ret_result=$(( ${ret_result} | $? ))
           fi
	fi

	return ${ret_result}
}

#Usage and help info for the script
help_usage(){
	echo "script usage: $(basename $0) [-f \"Folder to be used as logs residence(Can be omitted/Default to /tmp/virt_logs_residence)\"] \
[-l \"Extra folders or files to be collected as host logs,for example,\"log_file_1 log_file_2 log_folder_1\"(Can be omitted/Default to nothing)\"] \
[-g \"guests to be involved or none,for example,\"guest1 guest2 guest3\"(Can be omitted/Default to all)\"] \
[-e \"Extra folders or files to be collected as guest logs, for example, \"log_file_1 log_file_2 log_folder_1\"(Can be omitted/Default to nothing)\"] \
[-h help]"
}

virt_logs_collecor_log="/var/log/virt_logs_collector.log"
virt_logs_folder=""
virt_extra_logs_host=""
virt_extra_logs_guest=""
virt_guests_wanted=""
virt_logs_collector_result=0
rm -f ${virt_logs_collecor_log}

#Parse input arguments, all options are optional
#Any log paremter passed in should take absolute path form
while getopts 'f:l:g:e:h' OPTION; do
   case "$OPTION" in
      f)
        virt_logs_folder="$OPTARG"
        echo "The logs folder is ${virt_logs_folder}" | tee -a ${virt_logs_collecor_log}
        ;;
      l)
        virt_extra_logs_host="$OPTARG"
        echo "The extra host logs wanted are ${virt_extra_logs_host}" | tee -a ${virt_logs_collecor_log}
        ;;
      g)
        virt_guests_wanted="$OPTARG"
        if [[ ${virt_guests_wanted} == "" ]];then
           virt_guests_wanted="all"
        fi
        echo "The guests involved are ${virt_guests_wanted}" | tee -a ${virt_logs_collecor_log}
        ;;
      e)
        virt_extra_logs_guest="$OPTARG"
        echo "The extra guest logs wanted are ${virt_extra_logs_guest}" | tee -a ${virt_logs_collecor_log}
        ;;
      h)
        help_usage | tee -a ${virt_logs_collecor_log}
        exit 1
        ;;
      *)
        help_usage | tee -a ${virt_logs_collecor_log}
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
guest_macaddresses_array=""
guest_ipaddress="";
guest_hash_index=0
guest_current=""
dhcpd_lease_file="/var/lib/dhcp/db/dhcpd.leases"

#Install necessary packages
echo -e "Install necessary packages. zypper install -y sshpass nmap xmlstarlet expect" | tee -a ${virt_logs_collecor_log}
zypper install -y sshpass nmap xmlstarlet expect| tee -a ${virt_logs_collecor_log}

#Establish reachable networks and hosts database on host
#In ALP, podman network takes ~40 minutes to finish scan, but it's useless, so exclude it
subnets_in_route=`ip route show all | grep -v cni-podman0 | awk '{print $1}' | grep -v default`
subnets_scan_results=""
subnets_scan_index=0
echo -e "Subnets ${subnets_in_route[@]} are reachable on host judging by ip route show all" | tee -a ${virt_logs_collecor_log}
echo -e "Establishing reachable hosts in subnets ${subnets_in_route[@]} database on host" | tee -a ${virt_logs_collecor_log}
for single_subnet in ${subnets_in_route[@]};do
    single_subnet_transformed=${single_subnet//./_}
    single_subnet_transformed=${single_subnet_transformed/\//_}
    scan_timestamp=`date "+%F-%H-%M-%S"`
    mkdir -p "${virt_logs_folder}/nmap_subnets_scan_results"
    single_subnet_scan_results=${virt_logs_folder}'/nmap_subnets_scan_results/nmap_scan_'${single_subnet_transformed}'_'${scan_timestamp}
    subnets_scan_results[${subnets_scan_index}]=${single_subnet_scan_results}
    echo -e "nmap -sn $single_subnet -oX $single_subnet_scan_results" | tee -a ${virt_logs_collecor_log}
    nmap -T4 -sn $single_subnet -oX $single_subnet_scan_results  | tee -a ${virt_logs_collecor_log}
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
    echo -e ${guest_current}:${guest_hash_ipaddr[${guest_hash_index}]} | tee -a ${virt_logs_collecor_log}
    guest_hash_index=$(( ${guest_hash_index} + 1 ))
done

#Start collecing logs from host and virtual machine
setup_common_logs_folder ${virt_logs_folder}	
echo -e "collect_system_log_and_diagnosis ${virt_logs_folder} host" | tee -a ${virt_logs_collecor_log}
collect_system_log_and_diagnosis ${virt_logs_folder} host | tee -a ${virt_logs_collecor_log}
virt_logs_collector_result=$(( ${virt_logs_collector_result} | $? ))
echo -e "collect_extra_logs_from_host ${virt_logs_folder} ${virt_extra_logs_host}" | tee -a ${virt_logs_collecor_log}
collect_extra_logs_from_host ${virt_logs_folder} "" ${virt_extra_logs_host} | tee -a ${virt_logs_collecor_log}
virt_logs_collector_result=$(( ${virt_logs_collector_result} | $? ))
if [[ ${virt_guests_wanted} == "none" ]];then
   echo -e "Will not collect supportconfig from any guest.\n" | tee -a ${virt_logs_collecor_log}
else
   guest_hash_index=0
   for guest_current in ${guest_domains_array[@]};do
       if [[ ${virt_guests_wanted} == "all" ]] || [[ ${virt_guests_wanted} =~ .*${guest_current}.* ]];then
          if [[ ${guests_inactive_array[@]} =~ .*${guest_current}.* ]];then 
             echo -e "Virtual machine ${guest_current} in shutdown state. Skip collecting logs from it." | tee -a ${virt_logs_collecor_log}
          else
             echo -e "collect_system_log_and_diagnosis ${virt_logs_folder} guest ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current}" | tee -a ${virt_logs_collecor_log}
             collect_system_log_and_diagnosis ${virt_logs_folder} guest ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current} | tee -a ${virt_logs_collecor_log}
             virt_logs_collector_result=$(( ${virt_logs_collector_result} | $? ))
             echo -e "collect_extra_logs_from_guest ${virt_logs_folder} ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current}  ${virt_extra_logs_guest}" | tee -a ${virt_logs_collecor_log}
             collect_extra_logs_from_guest ${virt_logs_folder} ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current} ${virt_extra_logs_guest} | tee -a ${virt_logs_collecor_log}
             virt_logs_collector_result=$(( ${virt_logs_collector_result} | $? ))
          fi
       else
          echo -e "Virtual machine ${guest_current} is not wanted. Skip collecting logs from it." | tee -a ${virt_logs_collecor_log} 
       fi
       guest_hash_index=$(( ${guest_hash_index} + 1 ))
   done
fi
exit ${virt_logs_collector_result}
