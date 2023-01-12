#!/bin/bash

#Determine whether log file is text file
function is_text_file() {
	local log_file=$1

	if [[ `file ${log_file} | grep ":.*text"` ]];then
	   echo "YES"
	else
	   echo "NO"
	fi
}

#Determine whether log file is empty file
function is_empty_file() {
	local log_file=$1

	if [[ `file ${log_file} | grep ":.*empty"` ]];then
	   echo "YES"
	else
	   echo "NO"
	fi
}

#Empty text log file or rm empty text log file
function cleanup_single_file() {
	local file_path=$1

	is_text=`is_text_file ${file_path}`
	is_empty=`is_empty_file ${file_path}`
	if [[ ${is_text} == "YES" ]];then
	   > ${file_path}
	   echo -e "Cleaned up text log file ${file_path}."
	   return 1
	elif [[ ${is_empty} == "YES" ]];then
	   rm -f -r ${file_path}
	   echo -e "Removed empty log file ${file_path}."
	   return 1
	else
	   return 0
	fi
}

#Clean log files or folders by using recursive algorithm
function cleanup_logs() {
	local logs_path=$1
	local total_text_file=0
	local is_text=""
	local is_empty=""
	local eachlog=""

	if [[ -f ${logs_path} ]];then
	   cleanup_single_file ${logs_path}
	   total_text_file=$(( ${total_text_file} + $? ))
	elif [[ -d ${logs_path} ]];then
	   if [[ `echo ${logs_path} | tr '[A-Z]' '[a-z]'` =~ .*image.* ]];then
	      echo -e "Skip image folder ${logs_path}."
	   else
	      for eachlog in `ls ${logs_path}`;do
	          if [[ -f ${logs_path}/${eachlog} ]];then
	             cleanup_single_file ${logs_path}/${eachlog}
	             total_text_file=$(( ${total_text_file} + $? ))
	          else
	             pushd ${logs_path}/${eachlog} &> /dev/null
	             cleanup_logs ${logs_path}/${eachlog}
	             total_text_file=$(( ${total_text_file} + $? ))
	             popd &> /dev/null
	          fi
	      done
	   fi
	else
	   echo -e "${logs_path} is not a file or folder." | tee -a ${clean_up_virt_logs_log}
	   return 0
	fi	   

	return ${total_text_file}
}

#Do logs cleanup on host with regard to /var/lib/libvirt, /var/log/libvirt and /var/log/xen. And calculate the total number of files that are cleaned
function do_cleanup_on_host() {
	local extra_logs=($@)
	local default_logs=("/var/log/libvirt" "/var/log/xen")
	local ret_result=0
	local total_cleanup=0
	local eachlog=""

	unset logs_list
	declare -a logs_list=("${default_logs[@]}")
	if [[ ${extra_logs[@]} != "" ]];then
	   logs_list=("${logs_list[@]}" "${extra_logs[@]}")
	fi
	for eachlog in ${logs_list[@]};do
	    echo -e "Going to clean up all empty and text log files in ${eachlog}." | tee -a ${clean_up_virt_logs_log}
	    cleanup_logs ${eachlog}
	    ret_result=$?
	    echo -e "Cleaned up ${ret_result} empty and text log files in ${eachlog}." | tee -a ${clean_up_virt_logs_log}
	    total_cleanup=$(( ${total_cleanup} + ${ret_result} ))
	done

	if [[ ${total_cleanup} -gt 0 ]];then
	   echo -e "Cleaned up ${total_cleanup} empty and text log files in total." | tee -a ${clean_up_virt_logs_log}
	   return 0
	else
	   echo -e "Did not clean up any empty or text log files." | tee -a ${clean_up_virt_logs_log}
	   return 1
	fi
}

#Just power on or reboot active guests to give them a clear start
function do_cleanup_on_guests() {
	local guest_domain_types="sles|alp"
	local guests_inactive_array=`virsh list --inactive | grep -Ei "${guest_domain_types}" | awk '{print $2}'`
	local guest_domains_array=`virsh list  --all | grep -Ei "${guest_domain_types}" | awk '{print $2}'`
	local guest_current=""
	local ret_result=0

	for guest_current in ${guest_domains_array[@]};do
	    if [[ ${guests_inactive_array[@]} =~ .*${guest_current}.* ]];then
	       echo -e "Virtual machine ${guest_current} was inactive. Going to start it." | tee -a ${clean_up_virt_logs_log}
	       echo -e "virsh start ${guest_current}"
	       virsh start ${guest_current}
	       ret_result=$(( ${ret_result} | $? ))
	    else
	       echo -e "Virtual machine ${guest_current} was running. Going to reboot it." | tee -a ${clean_up_virt_logs_log}
	       echo -e "virsh reboot ${guest_current}"
	       virsh reboot ${guest_current}
	       ret_result=$(( ${ret_result} | $? ))
	    fi
	done

	return ${ret_result}
}

#Usage and help info for the script
help_usage(){
	echo "script usage: $(basename $0) [-l \"Extra folders or files to be cleaned up on host,for example,\"log_file_1 log_file_2 log_folder_1\"(Can be omitted/Default to nothing)\"] [-h help]"
}

clean_up_virt_logs_log="/var/log/clean_up_virt_logs.log"
virt_extra_logs_host=""
clean_up_virt_logs_result=0
rm -f -r ${clean_up_virt_logs_log}

#Parse input arguments, all options are optional
#Any log parameter passed in takes absolute path form
while getopts 'l:h' OPTION; do
   case "$OPTION" in
      l)
        virt_extra_logs_host="$OPTARG"
        echo "The extra logs to be cleaned up are ${virt_extra_logs_host}" | tee -a ${clean_up_virt_logs_log}
        ;;
      h)
        help_usage | tee -a ${clean_up_virt_logs_log}
        exit 1
        ;;
      *)
        help_usage | tee -a ${clean_up_virt_logs_log}
        exit 1
        ;;
   esac
done
shift "$(($OPTIND -1))"

do_cleanup_on_host ${virt_extra_logs_host}
clean_up_virt_logs_result=$(( ${clean_up_virt_logs_result} | $? ))
do_cleanup_on_guests
clean_up_virt_logs_result=$(( ${clean_up_virt_logs_result} | $? ))
exit ${clean_up_virt_logs_result}
