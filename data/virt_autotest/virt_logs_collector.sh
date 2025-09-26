#!/bin/bash -x
set -o pipefail
shopt -s nocasematch

# Get Product name
# Product name are "SLES", "openSUSE Tumbleweed", "openSUSE Leap"
# TBD: ALP, ...
# Argument explanation:
# version_file: File from which release info is obtained.
function get_product_name() {
	local version_file=$1
	if [[ -z ${version_file} ]];then
	    version_file="/etc/os-release"
	fi
	local product_name=`cat /etc/os-release | grep ^NAME= | cut -d '"' -f2`
	echo $product_name
}

# Obtain SLES release version and service pack level.
# Argument explanation:
# query_type: major release or minor service pack.
# version_file: File from which release info is obtained.
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

# Get host hypervisor type
function get_sles_hypervisor() {
        (lsmod | grep -i kvm || dmesg | grep -i kvm) &> /dev/null
        if [[ $? -eq 0 ]];then
           echo "KVM"
        else
           echo "XEN"
        fi
}

# Setup folder on host to be used as logs warehouse which will hold all host and
# guest logs at the last.
# Arguments explanatiion:
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# Please also refer to script help_usage().
function setup_common_logs_folder() {
        local logs_folder=$1
        mkdir -p ${logs_folder}
        chmod -R 777 ${logs_folder}
        return $?
}

# Collect any desired logs from virtual machine by using virsh console and expect script
# Arguments explanatiion:
# guest_domain: Guest name can be used with libvirt or libguestfs.
# guest_password: Guest password with which ssh connection can be established.
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# full_supportconfig: Whether run supportconfig command with -A: Activates all
# supportconfig functions with additional logging and full rpm verification.
# extra_logs: Extra logs, supportconfig or sosreport log to be collected on guest
# because this function is called in collect_supportconfig_via_guest_console,
# collect_sosreport_via_guest_console and collect_extra_logs_via_guest_console to
# collect logs in the same manner.
# supportconfig_excluded_features_ref: Pointer to list of features to be excluded
# from being collected via supportconfig.
# Please also refer to script help_usage().
function collect_logs_via_guest_console() {
        local guest_domain=$1
        local guest_password=$2
        local logs_folder=$3
        local full_supportconfig=${4:-true}
        if [[ $5 == "support_config" ]] || [[ $5 == "sos_report" ]];then
            local extra_logs=$5
        else 
            local -n extra_logs_ref=$5
            local extra_logs="${extra_logs_ref[@]}"
        fi
        local -n supportconfig_excluded_features_ref=$6
        local supportconfig_excluded_features="${supportconfig_excluded_features_ref[@]}"
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
set guest_password [lindex \$argv 3]
set logs_folder [lindex \$argv 4]
set extra_logs [lindex \$argv 5]
set full_supportconfig [lindex \$argv 6]
set supportconfig_excluded_features [lindex \$argv 7]
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
         -nocase "password:" {send "${guest_password}\rcd ~\r"; exp_continue -continue_timer}
         -nocase "mistake|wrong|fault|error|fail|exception|not*found|timed*out" {puts "Can not login virsh console to \${guest_domain}\r"; set ret_result 1}
      }

      if { \${ret_result} == 0 } {
         set timeout 1200
         expect -re "~( |\\\])#"
         send "mkdir -p \${logs_folder};export time_stamp=\`date \'+%Y%m%d%H%M%S\'\`\r"
         expect -re "~( |\\\])#"
         if { \${extra_logs} == {support_config} } {
            send "rm -f -r \${logs_folder}/*supportconfig*\r"
            send "export excluded_features=\"\"\r"
            send "for feature in ${supportconfig_excluded_features};do if supportconfig -F | grep -i \\\$feature &> /dev/null;then excluded_features=\"\\\${excluded_features},\\\$feature\";fi;done\r"
            send "excluded_features=\\\${excluded_features#,}\r"
            send "echo GRAB_THIS:\\\${excluded_features}\r"
            expect -re "GRAB_THIS:(.*)\r" {
                set excluded_features \$expect_out(1,string)
                set excluded_features [string trim \$excluded_features "\r\n"]
            }
            send "echo ${excluded_features}\r"
            send "export supportconfig_cmd=\"supportconfig -y\"\r"
            if { \${excluded_features} != "" } {
                send "supportconfig_cmd=\"\\\${supportconfig_cmd} -x \${excluded_features}\"\r"
            }
            send "supportconfig_cmd=\"\\\${supportconfig_cmd} -t \${logs_folder} -B guest_\${guest_transformed}_supportconfig_\\\${time_stamp}\"\r"
            if { ${full_supportconfig} == {true} } {
                send "echo \"\\\${supportconfig_cmd} -A\"\r"
                send "\\\${supportconfig_cmd} -A\r"
            }
            if { ${full_supportconfig} == {false} } {
                send "echo \"\\\${supportconfig_cmd}\"\r"
                send "\\\${supportconfig_cmd}\r"
            }
         }
         if { \${extra_logs} == {sos_report} } {
            send "rm -f -r \${logs_folder}/*sosreport*\r"
            send "echo \"sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir \${logs_folder}\"\r"
            send "sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir \${logs_folder}\r"
         }
         if { \${extra_logs} != {support_config} && \${extra_logs} != {sos_report} && \${extra_logs} != "" } {
            send "rm -f -r \${logs_folder}/*extra_logs*\r"
            send "echo \"mkdir -p \${logs_folder}/guest_\${guest_transformed}_extra_logs;cp --parent -r -f \${extra_logs} \${logs_folder}/guest_\${guest_transformed}_extra_logs\"\r"
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
	echo -e "expect ${expfile} "${hypervisor}" "${guest_domain}" "${guest_transformed}" "${guest_password}" "${logs_folder}" "${extra_logs}" "${supportconfig_excluded_features}""
	expect ${expfile} "${hypervisor}" "${guest_domain}" "${guest_transformed}" "${guest_password}" "${logs_folder}" "${extra_logs}" "${supportconfig_excluded_features}"
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

# This function supports collecting supportconfig or sosreport from both host and
# guest. The argument target_type will be given 'host' or 'guest'.  Will resort to
# guest virsh console if collecting from guest ssh failed. Collecting logs from host
# only supports local host. Typical usage: collect_system_log_and_diagnosis logs_folder
# host or collect_system_log_and_diagnosis logs_folder guest guest_ip guest_domain_name.
# Collect any desired logs from virtual machine by using virsh console and expect script
# Arguments explanatiion:
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# target_type: host or guest
# target_ipaddr: Target ip address to which ssh connection can be established. 
# target_domain: Target domain name which is mainly used with guest libvirt or
# libguestfs.  
# target_password: Target password to be used with ssh or console connection. 
# full_supportconfig: Whether run supportconfig command with -A: Activates all
# supportconfig functions with additional logging and full rpm verification.
# supportconfig_excluded_features_ref: Pointer to list of features to be excluded
# from being collected via supportconfig.
# Please also refer to script help_usage().
function collect_system_log_and_diagnosis() {
	local logs_folder=$1
	local target_type=$2
	local target_ipaddr=$3
	local target_domain=$4
	local target_password=$5
	local full_supportconfig=${6:-true}
	local -n supportconfig_excluded_features=$7
	local target_user=""
	local target_pass=""
	local sshpass_ssh_cmd=""

	if [[ ${target_type} == "guest" ]];then
	   target_user="root"
	   target_pass=${target_password}
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
	   if [[ ${target_type} == "host" && `cat /etc/os-release` =~ oracle|rhel|red.*hat|fedora ]] || [[ ${target_type} == "guest" && ${target_transformed} =~ oracle|rhel|fedora ]];then
	      ${sshpass_ssh_cmd} rm -f -r ${logs_folder}/*sosreport*
	      echo -e "${sshpass_ssh_cmd} mkdir -p ${logs_folder}"
	      echo -e "${sshpass_ssh_cmd} sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir ${logs_folder}"
	      ${sshpass_ssh_cmd} mkdir -p ${logs_folder}
	      ${sshpass_ssh_cmd} sosreport --batch --debug -v --alloptions --all-logs -z xz --tmp-dir ${logs_folder}
	   else	   
    	      local time_stamp=`date '+%Y%m%d%H%M%S'`
	      ${sshpass_ssh_cmd} rm -f -r ${logs_folder}/*supportconfig*
	      local excluded_features=""
	      for feature in ${supportconfig_excluded_features[@]};do if supportconfig -F | grep -i $feature &> /dev/null;then excluded_features="${excluded_features},$feature";fi;done
	      excluded_features=${excluded_features#,}
	      supportconfig_cmd="${sshpass_ssh_cmd} supportconfig -y"
	      if [[ ${excluded_features} != "" ]];then
	          supportconfig_cmd="${supportconfig_cmd} -x ${excluded_features}"
	      fi
	      supportconfig_cmd="${supportconfig_cmd} -t ${logs_folder} -B ${target_type}_${target_transformed}_supportconfig_${time_stamp}"
	      if [[ ${full_supportconfig} == "true" ]];then
	          echo -e "${supportconfig_cmd} -A"
	          ${supportconfig_cmd} -A
	      else
	          echo -e "${supportconfig_cmd}"
	          ${supportconfig_cmd}
	      fi
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
	      echo -e "collect_sosreport_via_guest_console ${target_domain} ${target_password} ${logs_folder} ${full_supportconfig} ${supportconfig_excluded_features[*]}"
	      collect_sosreport_via_guest_console ${target_domain} ${target_password} ${logs_folder} ${full_supportconfig} supportconfig_excluded_features
	   else 
	      echo -e "collect_supportconfig_via_guest_console ${target_domain} ${target_password} ${logs_folder} ${full_supportconfig} ${supportconfig_excluded_features[*]}"
	      collect_supportconfig_via_guest_console ${target_domain} ${target_password} ${logs_folder} ${full_supportconfig} supportconfig_excluded_features
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

# This function supports collecting supportconfig from guest console.
# Arguments explanatiion:
# guest_domain: Guest name can be used with libvirt or libguestfs.
# guest_password: Guest password to be used with ssh or console connection.
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# full_supportconfig: Whether run supportconfig command with -A: Activates all
# supportconfig functions with additional logging and full rpm verification.
# supportconfig_excluded_features_ref: Pointer to list of features to be excluded
# from being collected via supportconfig.
# Please also refer to script help_usage().
function collect_supportconfig_via_guest_console() {
        local guest_domain=$1
        local guest_password=$2
        local logs_folder=$3
        local full_supportconfig=${4:-true}
        local -n supportconfig_excluded_features_via_guest_console=$5
        collect_logs_via_guest_console ${guest_domain} ${guest_password} ${logs_folder} ${full_supportconfig} support_config supportconfig_excluded_features_via_guest_console
        if [[ $? -eq 0 ]];then
           return 0
        else
           return 1
        fi
}

# This function supports collecting sosreport from guest console.
# Arguments explanatiion:
# guest_domain: Guest name can be used with libvirt or libguestfs.
# guest_password: Guest password to be used with ssh or console connection.
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# full_supportconfig: Whether run supportconfig command with -A: Activates all
# supportconfig functions with additional logging and full rpm verification.
# supportconfig_excluded_features_ref: Pointer to list of features to be excluded
# from being collected via supportconfig.
# Please also refer to script help_usage().
function collect_sosreport_via_guest_console() {
        local guest_domain=$1
        local guest_password=$2
        local logs_folder=$3
        local full_supportconfig=${4:-true}
        local -n supportconfig_excluded_features_via_guest_console=$5
        collect_logs_via_guest_console ${guest_domain} ${guest_password} ${logs_folder} ${full_supportconfig} sos_report supportconfig_excluded_features_via_guest_console
        if [[ $? -eq 0 ]];then
           return 0
        else
           return 1
        fi
}

# This function supports collecting extra logs from guest console.
# Arguments explanatiion:
# guest_domain: Guest name can be used with libvirt or libguestfs.
# guest_password: Guest password to be used with ssh or console connection.
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# full_supportconfig: Whether run supportconfig command with -A: Activates all
# supportconfig functions with additional logging and full rpm verification.
# extra_logs_via_guest_console: Pointer to list of extra logs to collected on
# guest. 
# supportconfig_excluded_features_ref: Pointer to list of features to be excluded
# from being collected via supportconfig.
# Please also refer to script help_usage().
function collect_extra_logs_via_guest_console() {
        local guest_domain=$1
        local guest_password=$2
        local logs_folder=$3
        local full_supportconfig=${4:-true}
        local -n extra_logs_via_guest_console=$5
        local -n supportconfig_excluded_features_via_guest_console=$6
        collect_logs_via_guest_console ${guest_domain} ${guest_password} ${logs_folder} ${full_supportconfig} extra_logs_via_guest_console supportconfig_excluded_features_via_guest_console
        if [[ $? -eq 0 ]];then
           return 0
        else
           return 1
        fi
}

# Collect any extra logs wanted from guest. Will resort to guest virsh console
# if collecting from ssh failed.
# Arguments explanatiion:
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# guest_ipaddr: Guest IP address to which ssh connection can be established.
# guest_domain: Guest name can be used with libvirt or libguestfs.
# guest_password: Guest password to be used with ssh or console connection.
# full_supportconfig: Whether run supportconfig command with -A: Activates all
# supportconfig functions with additional logging and full rpm verification.
# supportconfig_excluded_features_ref: Pointer to list of features to be excluded
# from being collected via supportconfig.
# extra_logs: Pointer to list of extra logs to collected on
# guest. 
# Please also refer to script help_usage().
function collect_extra_logs_from_guest() {
        local logs_folder=$1
        local guest_ipaddr=$2
        local guest_domain=$3
        local guest_password=$4
        local full_supportconfig=${5:-true}
        local -n supportconfig_excluded_features=$6
        local -n extra_logs=$7
      
        if [[ "${extra_logs[*]}" != "" ]];then
           local guest_user="root"
           local guest_pass=${guest_password}
           local sshpass_ssh_cmd="sshpass -p ${guest_pass} ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${guest_user}@${guest_ipaddr}"
           local guest_transformed=${guest_domain//./_}
           local ret_result=128
           local retry_times=0
           while [[ ${retry_times} -lt 2 ]] && [[ ${ret_result} -ne 0 ]];
           do
                 ${sshpass_ssh_cmd} rm -f -r ${logs_folder}/guest_${guest_transformed}_extra_logs
                 ${sshpass_ssh_cmd} mkdir -p ${logs_folder}/guest_${guest_transformed}_extra_logs
                 echo -e "${sshpass_ssh_cmd} cp --parent -r -f ${extra_logs[*]} ${logs_folder}/guest_${guest_transformed}_extra_logs"
                 ${sshpass_ssh_cmd} cp --parent -r -f ${extra_logs[*]} ${logs_folder}/guest_${guest_transformed}_extra_logs
                 ret_result=$?
                 if [[ ${ret_result} -eq 0 ]];then
                    echo -e "Successfully collected ${extra_logs[*]} from guest ${guest_domain} via ssh."
                    break
                 fi
                 retry_times=$((${retry_times}+1))
           done
           if [[ ${ret_result} -ne 0 ]];then
              echo -e "Can not collect ${extra_logs[*]} from guest ${guest_domain} via ssh. Try to use guest virsh console"
              echo -e "collect_extra_logs_via_guest_console ${guest_domain} ${guest_password} ${logs_folder} ${full_supportconfig} ${supportconfig_excluded_features[*]} ${extra_logs[*]}"
              collect_extra_logs_via_guest_console ${guest_domain} ${guest_password} ${logs_folder} ${full_supportconfig} extra_logs supportconfig_excluded_features
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

# Collect any extra wanted logs from host. And provide more complete virtualization
# logs for SLE-11-SP4 ,SLE-12 and SLE-15 hosts.
# Arguments explanatiion:
# logs_folder: The folder hosts all logs collected from host or guest. It is the
# top logs residence to/from which all logs are stored/fetched.
# target_domain: Host domain name to help form sub-folder to host extra logs. 
# extra_logs: Pointer to list of extra logs to collected on host. 
# Please also refer to script help_usage().
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
	local libvirt_daemon_logs="${libvirt_log}/*d.log"
	local xen_log="/var/log/xen"
	local xen_boot_log="${xen_log}/xen-boot.log"
        local kernel_log="/var/log/kern.log"

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
        elif [[ ${release} -eq 15 || `get_product_name` == "openSUSE Tumbleweed" ]];then
           cp --parent -f -r ${libvirt_boot_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
           cp --parent -f -r ${libvirt_qemu_log} ${extra_logs_folder}
           ret_result=$(( ${ret_result} | $? ))
	   cp --parent -f -r ${libvirt_daemon_logs} ${extra_logs_folder}
	   ret_result=$(( ${ret_result} | $? ))
           if [[ `get_sles_hypervisor` == "XEN" ]];then
              cp --parent -f -r ${xen_boot_log} ${extra_logs_folder}
              ret_result=$(( ${ret_result} | $? ))
           fi
	fi
        
	if [ -f ${kernel_log} ];then
            cp --parent -f -r ${kernel_log}* ${extra_logs_folder} 
            ret_result=$(( ${ret_result} | $? ))
        fi

	return ${ret_result}
}

#Usage and help info for the script
help_usage(){
	echo "script usage: $(basename $0) [-f \"Folder to be used as logs residence(Can be omitted/Default to /tmp/virt_logs_residence)\"] \
[-l \"Extra folders or files to be collected as host logs,for example,\"log_file_1 log_file_2 log_folder_1\"(Can be omitted/Default to nothing)\"] \
[-g \"guests to be involved or none,for example,\"guest1 guest2 guest3\"(Can be omitted/Default to all)\"] \
[-p \"Root password to access all guests\"] \
[-e \"Extra folders or files to be collected as guest logs, for example, \"log_file_1 log_file_2 log_folder_1\"(Can be omitted/Default to nothing)\"] \
[-a \"Activating all supportconfig functions or not, for example, \"true\" or \"false\"(Can be omitted/Default to true)\"] \
[-x \"Features to be excluded from supportconfig log, for example, \"aFSLIST AUDIT SELINUX\" or \"\"(Can be omitted/Default to \"aFSLIST AUDIT SELINUX\")\"] \
[-h help]"
}

virt_logs_collecor_log="/var/log/virt_logs_collector.log"
virt_logs_folder=""
virt_extra_logs_host=""
virt_extra_logs_guest=""
virt_guests_wanted=""
virt_guests_password="novell"
virt_logs_collector_result=0
all_supportconfig_functions="true"
excluded_supportconfig_features="aFSLIST AUDIT SELINUX"
rm -f ${virt_logs_collecor_log}

#Parse input arguments, all options are optional
#Any log paremter passed in should take absolute path form
while getopts 'f:l:g:p:e:a:x:h' OPTION; do
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
      p)
        virt_guests_password="$OPTARG"
        echo "Root password to access all guests [redacted]" | tee -a ${virt_logs_collecor_log}
        ;;
      e)
        virt_extra_logs_guest="$OPTARG"
        echo "The extra guest logs wanted are ${virt_extra_logs_guest}" | tee -a ${virt_logs_collecor_log}
        ;;
      a)
        all_supportconfig_functions="$OPTARG"
        echo "Activating all supportconfig functions is ${all_supportconfig_functions}" | tee -a ${virt_logs_collecor_log}
        ;;
      x)
        excluded_supportconfig_features="$OPTARG"
        echo "Features to be excluded from supportconfig log are ${excluded_supportconfig_features}" | tee -a ${virt_logs_collecor_log}
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
declare -a virt_extra_logs_guest=($virt_extra_logs_guest)
declare -a excluded_supportconfig_features=($excluded_supportconfig_features)
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
    echo -e "nmap -T4 -sn --exclude 127.0.0.0/8 $single_subnet -oX $single_subnet_scan_results" | tee -a ${virt_logs_collecor_log}
    nmap -T4 -sn --exclude 127.0.0.0/8 $single_subnet -oX $single_subnet_scan_results  | tee -a ${virt_logs_collecor_log}
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
echo -e "collect_system_log_and_diagnosis ${virt_logs_folder} host n/a n/a n/a ${all_supportconfig_functions} ${excluded_supportconfig_features[*]}"  | tee -a ${virt_logs_collecor_log}
collect_system_log_and_diagnosis ${virt_logs_folder} host "" "" "" ${all_supportconfig_functions} excluded_supportconfig_features | tee -a ${virt_logs_collecor_log}
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
             echo -e "collect_system_log_and_diagnosis ${virt_logs_folder} guest ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current} ${virt_guests_password} ${all_supportconfig_functions} ${excluded_supportconfig_features[*]}" | tee -a ${virt_logs_collecor_log}
             collect_system_log_and_diagnosis ${virt_logs_folder} guest ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current} ${virt_guests_password} ${all_supportconfig_functions} excluded_supportconfig_features | tee -a ${virt_logs_collecor_log}
             virt_logs_collector_result=$(( ${virt_logs_collector_result} | $? ))
             echo -e "collect_extra_logs_from_guest ${virt_logs_folder} ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current} ${virt_guests_password} ${all_supportconfig_functions} ${excluded_supportconfig_features[*]} ${virt_extra_logs_guest[*]}" | tee -a ${virt_logs_collecor_log}
             collect_extra_logs_from_guest ${virt_logs_folder} ${guest_hash_ipaddr[${guest_hash_index}]} ${guest_current} ${virt_guests_password} ${all_supportconfig_functions} excluded_supportconfig_features virt_extra_logs_guest | tee -a ${virt_logs_collecor_log}
             virt_logs_collector_result=$(( ${virt_logs_collector_result} | $? ))
          fi
       else
          echo -e "Virtual machine ${guest_current} is not wanted. Skip collecting logs from it." | tee -a ${virt_logs_collecor_log} 
       fi
       guest_hash_index=$(( ${guest_hash_index} + 1 ))
   done
fi
exit ${virt_logs_collector_result}
