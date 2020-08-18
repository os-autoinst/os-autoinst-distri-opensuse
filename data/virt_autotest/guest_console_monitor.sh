#!/bin/bash

#PREPARATION
#Usage and help info for the script
function help_usage() {

    echo "script usage: $(basename $0) [-s Start Monitor for guest console] [-e End of Monitor for guest console ] [-h help]"
}

monitor_log_file="/tmp/guest_console_monitor.log"
#Quit if there are less than one argument
if [ $# -eq 0 ];then
    help_usage | tee -a ${monitor_log_file}
    exit 1
fi

##CONFIG PART
START_MONITOR="0"
END_MONITOR="0"
MONITOR_LOCKED_FILE="/tmp/GUEST_CONSOLE_COLLECTOR_SEMAPHORE"
LOG_DIR="/tmp/virt_logs_residence"
###CHECK EXISTED GUEST
vm_guestnames_types="sles"
get_vm_guestnames_inactive=`virsh list --inactive | grep "${vm_guestnames_types}" | awk '{print $2}'`
vm_guestnames_inactive_array=$(echo -e ${get_vm_guestnames_inactive})
get_vm_guestnames=`virsh list  --all | grep "${vm_guestnames_types}" | awk '{print $2}'`
vm_guestnames_array=$(echo -e ${get_vm_guestnames})
vmguest=""
vmguest_failed="0"

#Parse input arguments. -s or -e must have values
while getopts "seh" OPTION; do
  case "${OPTION}" in
    s)
      START_MONITOR="1"
      ;;
    e)
      END_MONITOR="1"
      ;;
    h)
      help_usage | tee -a ${monitor_log_file}
      exit 1
      ;;
    *)
      help_usage | tee -a ${monitor_log_file}
      exit 1
      ;;
  esac
done

#FUNCTION PART
function get_console() {

local vmguest=$1

expect -c "
set timeout 60

##hide echo
log_user 0
spawn -noecho virsh console ${vmguest}

#wait connection
sleep 3
send \"\r\n\r\n\r\n\"

#condition expect
expect {
        \"*login:\" {
                send \"root\r\"
                exp_continue
        }
        -nocase \"password:\" {
                send \"novell\r\"
                exp_continue
        }
        \"*:~ #\" {
                send -- \"ip route get 1\r\"
        }
        timeout {
                send -- \"exit\r\"
                exp_continue        
        }                 
}

## -1 means never timeout
set timeout -1

expect -re {dev.*\s([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})[^0-9]}

if {![info exists expect_out(1,string)]} {
        puts \"Match did not happen :(\"
}
set output \$expect_out(buffer)
expect eof

puts \"\$output\"
"

}

function open_console() {

    #open guest console
    for vmguest in ${vm_guestnames_state_running_array[@]};do
        get_console ${vmguest} >> ${LOG_DIR}/${vmguest}_console.log 2>&1 &
    done 
}

function close_console() {

    key_cmd=$@
    #close guest console
    ##There was a stop_sign as close_console_count, default setting as 0 - zero.
    ##After all or legacy motior commands were kill up as close_console() purpose
    ##setup close_console_count as 1 to end of this until loop
    close_console_count=0
    until [ "$close_console_count" -eq 1 ]
    do
        pid=`ps -eo pid,cmd | grep -E "${key_cmd}" | grep -v "grep"| awk '{print $1}'`
        if [[ -n $pid ]];then
            kill -9 $pid >> /dev/null 2>&1;sync
        else
            close_console_count=1
        fi
    done
}

function end_monitor() {

    #End of monitor for guest console
    if [ -f ${MONITOR_LOCKED_FILE} ];then
        echo -e "End of Monitor for guest console" | tee -a ${monitor_log_file}
        #UNLOCK Monitor for guest console
        rm -rf ${MONITOR_LOCKED_FILE} >> /dev/null 2>&1
        #Kill All Pids from Monitor for guest console
        MONITOR_CMD="guest_console_monitor.sh -s|expect -c|virsh console"
        close_console ${MONITOR_CMD}
    else
        #Kill Legacy Pids from Monitor for guest console        
        LEGACY_CMD="expect -c|virsh console"
        close_console ${LEGACY_CMD}
    fi
}

function start_monitor() {

    #Start monitor for guest console
    ##After boot up all existed vm guest(s) from set_guest_running func
    ##Figure out vm_guestnames_state_running_array from all existed and boot up vm guest(s) 
    get_vm_guestnames_state_running=`virsh list --state-running | grep "${vm_guestnames_types}" | awk '{print $2}'`
    vm_guestnames_state_running_array=$(echo -e ${get_vm_guestnames_state_running})

    while :
    do
        if [ -f ${MONITOR_LOCKED_FILE} ];then
            #KEEP LOCK-UP status
            #To let just only one virsh console with one vm guest as backgroup PID

            #wait for checking background PID of virsh console
            sleep 3
	    #Check with background PID of virsh console
	    for vmguest in ${vm_guestnames_array[@]};do
	        virsh list --state-running | grep ${vmguest}
                if [[ $? -eq 0 ]];then
                    ps aux | grep "virsh console ${vmguest}" | grep -v grep
                    if [[ $? -ne 0 ]];then
                        get_console ${vmguest} >> ${LOG_DIR}/${vmguest}_console.log 2>&1 &
                    fi
                 else
                    virsh list --inactive | grep ${vmguest} | grep -v grep
                    if [[ $? -eq 0 ]];then
                        echo "${vmguest} is not running now\n" >> ${monitor_log_file}
                        echo "No any output from virsh console ${vmguest}\n" >> ${monitor_log_file}
                    fi
                 fi
            done
        else
            echo -e "Create LOCK-UP for $(basename $0)\n" >> ${monitor_log_file}
            #SETUP LOCK-UP FILE
            touch ${MONITOR_LOCKED_FILE}
            #Start guest serial console
            open_console
        fi
    done
}

function set_guest_running() {

    #Boot up all existed vm guest(s) on vm host
    for vmguest in ${vm_guestnames_array[@]};do
        echo -e ${vm_guestnames_inactive_array[*]} | grep ${vmguest} >> /dev/null 2>&1
        if [[ $? -eq 0 ]];then
            virsh start ${vmguest}
            vmguest_failed=$((${vmguest_failed} | $(echo $?)))

            #Quit if at least one vm guest failed to start up as normal
            if [[ ${vmguest_failed} -ne 0 ]];then
                echo -e "Fail to boot up ${vmguest} as normal. Please investigate.\n" >> ${monitor_log_file}
                exit 1
            fi
        fi
    done
}

##MAIN PART
if [[ ! -d ${LOG_DIR} ]]; then
     mkdir -p ${LOG_DIR}
fi

if [[ ${START_MONITOR} -eq 1 ]];then

    #clean up environment before start monitor
    end_monitor

    #Remove guest_console_monitor log file if it already exists
    if [ -e ${monitor_log_file} ];then
        rm -rf ${monitor_log_file}
    fi

    #Install required packages
    zypper_cmd="zypper --non-interactive in psmisc procps coreutils expect"
    echo -e "${zypper_cmd} will be executed\n" >> ${monitor_log_file}
    ${zypper_cmd} >> /dev/null 2>&1

    #Boot up all existed vm guest(s) on vm host
    set_guest_running
    
    #Start Monitor for guest console
    echo -e "Start Monitor in background for guest console" | tee -a ${monitor_log_file}
    start_monitor >> /dev/null 2>&1 &
fi

if [[ ${END_MONITOR} -eq 1 ]];then
    end_monitor
fi

chmod a+rw ${monitor_log_file}
exit 0
