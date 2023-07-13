#!/bin/bash
#This script can be executed multiple times consecutively to facilitate establishing dns domain name access to virtual machines even virtual machine ip changes
#The ability of consecutive multiple runs is achieved by detecting signature "$0" written to various configuration files by this script, so the backup original configuration 
#files can be restored before executing this script again. In order to do so, please make sure the way in which this script is called is always the same every time
#Usage and help info for the script
help_usage(){
        echo "script usage: $(basename $0) [-f DNS forward domain name is mandatory(testvirt.net)] [-r DNS reverse domain name is mandatory(123.168.192)] [-s DNS server ip is mandatory (192.168.123.1)] [-h help]"
}
#Remove virt_dns_setup log file if it already exists
setup_log_file="/var/log/virt_dns_setup.log"
if [ -e ${setup_log_file} ];then
        rm -f ${setup_log_file}
fi

#At least six arguments are required. They are -f, dns forward domain, -r, dns reverse domain, -s and dns server ip
#Quit if there are less than six arguments
if [ $# -lt 6 ];then
	help_usage | tee -a ${setup_log_file}
	exit 1
fi
#Parse input arguments. -f, -r and -s must have values
while getopts 'f:r:s:h' OPTION; do
  case "$OPTION" in
    f)
      dns_domain_forward="$OPTARG"
      echo "The forward domain is $OPTARG" | tee -a ${setup_log_file}
      ;;
    r)
      dns_domain_reverse="$OPTARG"
      echo "The reverse domain is $OPTARG" | tee -a ${setup_log_file}
      #Quit if -r is given invalid value
      if [ -z $dns_domain_reverse ] || echo $dns_domain_reverse | grep -vEq "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"; then
	      echo "The given DNS DOMAIN REVERSE is not in correct format (for example, 123.168.192)" | tee -a ${setup_log_file}
              help_usage | tee -a ${setup_log_file}
	      exit 1
      fi  
      ;;
    s)
      bridgeip="$OPTARG"
      echo "The DNS server is $OPTARG" | tee -a ${setup_log_file}
      #Quit if -s is given invalid value
      if [ -z $bridgeip ] || echo $bridgeip | grep -vEq "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"; then
	      echo "The given BRIDGE IP is not in correct format (for example, 192.168.123.1)" | tee -a ${setup_log_file}
              help_usage | tee -a ${setup_log_file}
	      exit 1
      fi
      ;;
    h)
      help_usage | tee -a ${setup_log_file}
      exit 1
      ;;
    *)
      help_usage | tee -a ${setup_log_file}
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

#Restart dhcpd service with updated dhpcd parameters, including default-lease-time, max-lease-time, domain-name, 
#IP, NET, NETREV, NET_DHCP_RANGE_START, NET_DHCP_RANGE_END, NET_STATIC_RANGE_START and NET_DHCP_RANGE_END
dhcpd_config_file="/etc/dhcpd.conf"
dhcpd_lease_file="/var/lib/dhcp/db/dhcpd.leases"
qa_standalone_file="/usr/share/qa/qa_test_virtualization/shared/standalone"
cat ${dhcpd_config_file} | grep "#$0"
if [ $? -eq 0 ];then
        mv ${dhcpd_config_file}.orig ${dhcpd_config_file} #Restore ${dhcpd_config_file} if it was previously modified by this script
fi
cp $dhcpd_config_file $dhcpd_config_file.orig
sed -irn "s/^.*default-lease-time.*$/default-lease-time 28800;/g; s/^.*max-lease-time.*$/max-lease-time 28800;/g; s/^.*option domain-name .*$/option domain-name \"$dns_domain_forward\";/g" ${qa_standalone_file}
get_dhcp_ipaddr_range=`echo -e ${dns_domain_reverse} | awk -F"." 'BEGIN {OFS=".";} {print $3,$2,$1}'`
dhcp_ipaddr_range=$(echo -e ${get_dhcp_ipaddr_range})
sed -irn "s/^IP=.*$/IP=\'${bridgeip}\'/g; s/^NET=.*$/NET=\'${dhcp_ipaddr_range}\.0\'/g; s/^NETREV=.*$/NETREV=\'${dns_domain_reverse}\'/g; s/^NET_DHCP_RANGE_START=.*$/NET_DHCP_RANGE_START=\'${dhcp_ipaddr_range}\.10\'/g; s/^NET_DHCP_RANGE_END=.*$/NET_DHCP_RANGE_END=\'${dhcp_ipaddr_range}\.100\'/g; s/^NET_STATIC_RANGE_START=.*$/NET_STATIC_RANGE_START=\'${dhcp_ipaddr_range}\.101\'/g; s/^NET_STATIC_RANGE_END=.*$/NET_STATIC_RANGE_END=\'${dhcp_ipaddr_range}\.115\'/g" ${qa_standalone_file}
source ${qa_standalone_file}

#Insert script signature to the end of ${dhcpd_config_file}
echo -e "#$0" >> ${dhcpd_config_file}
#Install auxiliary packages
zypper_cmd="zypper --non-interactive in lsb-release bridge-utils bind bind-chrootenv bind-utils sshpass"
echo -e "${zypper_cmd} will be executed\n" | tee -a ${setup_log_file}
${zypper_cmd}

#Write {vmguestname => vmipaddress} key => value pairs into vm_guestnames_array and vm_hash_forward_ipaddr arrays
#The dictionary will be used to fill out the forward dns zone file
#Write {vmipaddress last part => vmguestname} key => value pairs into vm_guestnames_array and vm_hash_reverse_ipaddr arrays
#The dictionary will be used to fill out the reverse dns zone file
unset vm_hash_forward_ipaddr
unset vm_hash_reverse_ipaddr
declare -a vm_hash_forward_ipaddr=""
declare -a vm_hash_reverse_ipaddr=""
vm_guestnames_types="sles|win"
get_vm_guestnames_inactive=`virsh list --inactive | grep -E "${vm_guestnames_types}" | awk '{print $2}'`
vm_guestnames_inactive_array=$(echo -e ${get_vm_guestnames_inactive})
get_vm_guestnames=`virsh list  --all | grep -E "${vm_guestnames_types}" | awk '{print $2}'`
vm_guestnames_array=$(echo -e ${get_vm_guestnames})
get_vm_macaddress=""
vm_macaddresses_array=""
get_vm_ipaddress=""
vm_ipaddress="";
vm_ipaddress_lastpart=""
vm_hash_index=0
vmguest=""
vmguest_failed=0

#Start or reboot vm guest machines
for vmguest in ${vm_guestnames_array[@]};do
	echo -e ${vm_guestnames_inactive_array[*]} | grep ${vmguest}
        if [[ $? -eq 0 ]];then
		virsh start ${vmguest}
		vmguest_failed=$((${vmguest_failed} | $(echo $?)))
        else
            	virsh destroy ${vmguest}
            	virsh start ${vmguest}
	    	vmguest_failed=$((${vmguest_failed} | $(echo $?)))
        fi
done
#Quit if at least one vm guest failed to start up as normal
if [[ ${vmguest_failed} -ne 0 ]];then
	echo -e "At least one virtual machine can not be started up as normal. Please investigate.\n" | tee -a ${setup_log_file}	
	exit 1
fi
#Wait for vm guests get assigned ip addresses
sleep 90s
echo -e "Virtual machines ${vm_guestnames_array[@]} have already been refreshed\n" | tee -a ${setup_log_file}

#Write vm_hash_forward_ipaddr and vm_hash_reverse_ipaddr arrays
for vmguest in ${vm_guestnames_array[@]};do
        get_vm_macaddress=`virsh domiflist --domain ${vmguest} | grep -oE "([0-9|a-z]{2}:){5}[0-9|a-z]{2}"`
        vm_macaddresses_array[${vm_hash_index}]=$(echo -e ${get_vm_macaddress})
        get_vm_ipaddress=`tac $dhcpd_lease_file | awk '!($0 in S) {print; S[$0]}' | tac | grep -iE "${vm_macaddresses_array[${vm_hash_index}]}" -B8 | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | tail -1`
        vm_ipaddress=$(echo -e ${get_vm_ipaddress})
        #missing ip will make named fail to load domain zones due to malformed zone file
        if [ -z "$vm_ipaddress" ]; then
            echo -e "Unable to get the ip of $vmguest. Abort the test!\n" | tee -a ${setup_log_file}
            exit 1
        fi
        vm_ipaddress_lastpart=$(echo -e ${vm_ipaddress} | grep -Eo "[0-9]{1,3}$")
        vm_hash_forward_ipaddr[${vm_hash_index}]=${vm_ipaddress}
        vm_hash_reverse_ipaddr[${vm_hash_index}]=${vm_ipaddress_lastpart}
        vm_hash_index=$(($vm_hash_index + 1))
        echo -e ${vm_hash_forward_ipaddr[${vm_hash_index}]}
done

#Remove existing vm guests records in /etc/hosts to avoid conflicts
vm_name2ip_mapping_file="/etc/hosts"
for vmguest in ${vm_guestnames_array[@]};do
        sed -i "/[[:space:]]\{1,\}${vmguest}[[:space:]]\{0,\}.*$/d;/[[:space:]]\{1,\}${vmguest}\..*$/d" ${vm_name2ip_mapping_file}
done
echo -e "${vm_name2ip_mapping_file} file content after tidy-up:\n" | tee -a ${setup_log_file}
cat ${vm_name2ip_mapping_file} |  tee -a ${setup_log_file}

#Populate dns forward zone records by using vm_hash_forward_ipaddr generated
dns_forward_zone_file="/var/lib/named/${dns_domain_forward}.zone"
dns_reverse_zone_file="/var/lib/named/${dns_domain_reverse}.zone"
dns_record=""
dns_records_forward=""
dns_records_reverse=""
if [ -e ${dns_forward_zone_file} ];then
        rm -f ${dns_forward_zone_file}
fi
vm_hash_index=0
for vmguest in ${vm_guestnames_array[@]};do
	dns_record="${vmguest}\tIN\tA\t${vm_hash_forward_ipaddr[${vm_hash_index}]}"
        dns_records_forward="${dns_records_forward}\n${dns_record}"
	vm_hash_index=$(($vm_hash_index + 1))
done

#The content of testvirt.net zone file
cat > ${dns_forward_zone_file} <<EOF
; Authoritative data for ${dns_domain_forward} zone
\$ORIGIN         ${dns_domain_forward}.
\$TTL 1D
@   IN SOA  ns.${dns_domain_forward}.  mailmaster.${dns_domain_forward}. (
                                       $(date +%d%H%M%S)        ; serial
                                       1D              ; refresh
                                       1H              ; retry
                                       1W              ; expire
                                       3H )            ; minimum

                         IN      NS      ns.${dns_domain_forward}.

ns                             IN      A       ${bridgeip}
;;
$(echo -e ${dns_records_forward})
;;
; Mail server MX record
@            IN      MX      10      mailmaster.$dns_domain_forward.
mailmaster   IN      A       ${bridgeip}
EOF

#Populate dns reverse zone records by using vm_hash_reverse_ipaddr generated
if [ -e ${dns_reverse_zone_file} ];then
        rm -f ${dns_reverse_zone_file}
fi
vm_hash_index=0
for vmguest in ${vm_guestnames_array[@]};do
	dns_record="${vm_hash_reverse_ipaddr[${vm_hash_index}]}\tIN\tPTR\t${vmguest}."
        dns_records_reverse="${dns_records_reverse}\n${dns_record}"
	vm_hash_index=$(($vm_hash_index + 1))
done

#The content of 123.168.192.in-addr.arpa zone file
cat > ${dns_reverse_zone_file} <<EOF
; Authoritative data for ${dns_domain_reverse}.in-addr.arpa zone
; ?
\$ORIGIN ${dns_domain_reverse}.in-addr.arpa.
\$TTL 1D
@          IN SOA ns.${dns_domain_forward}. mailmaster.${dns_domain_forward}. (
              $(date +%d%H%M%S)          ; serial
              21600             ; refresh
              3600              ; retry
              3600000           ; expire
              86400 )           ; minimum


; ----------- ENREGISTREMENTS -----------
@                       IN NS                   ns.${dns_domain_forward}.
;;
$(echo -e ${dns_records_reverse})
;;
; ----------- ENREGISTREMENTS SPECIAUX -----------"
EOF

dns_config_file="/etc/named.conf"
dns_config_file_tmp="/etc/named.conf.tmp"
dns_service_name="named"
cat ${dns_config_file} | grep "#$0"
if [ $? -eq 0 ];then
	mv ${dns_config_file}.orig ${dns_config_file} #Restore ${dns_config_file} if it was previously modified by this script
fi
cp ${dns_config_file} ${dns_config_file}.orig

#The following forward zone info will be inserted into /etc/named.conf
#zone "testvirt.net" in {
#        type master;
#        file "testvirt.net.zone";
#};
awk -v dnsvar=${dns_domain_forward} 'done != 1 && /^zone.*$/ { print "zone \""dnsvar"\" in {\n        type master;\n        file \""dnsvar".zone\";\n};"; done=1 } 1' ${dns_config_file} > ${dns_config_file_tmp}
mv ${dns_config_file_tmp} ${dns_config_file}
echo -e "${dns_domain_forward} zone file content:\n" | tee -a ${setup_log_file}
cat ${dns_forward_zone_file} |  tee -a ${setup_log_file}

#The following reverse zone info will be inserted into /etc/named.conf
#zone "123.168.192.in-addr.arpa" in {
#        type master;
#        file "123.168.192.zone";
#};
awk -v dnsvar=${dns_domain_reverse} 'done != 1 && /^zone.*$/ { print "zone \""dnsvar".in-addr.arpa\" in {\n        type master;\n        file \""dnsvar".zone\";\n};"; done=1 } 1' ${dns_config_file} > ${dns_config_file_tmp}
mv ${dns_config_file_tmp} ${dns_config_file}
echo -e "\n${dns_domain_reverse} zone file content:\n" | tee -a ${setup_log_file}
cat ${dns_reverse_zone_file} |  tee -a ${setup_log_file}

#Add 192.168.123.1 as nameserver
dns_resolv_file="/etc/resolv.conf"
dns_resolv_file_tmp="/etc/resolv.conf.tmp"
cat ${dns_resolv_file} | grep "#$0"
if [ $? -eq 0 ];then
        mv ${dns_resolv_file}.orig ${dns_resolv_file} #Restore ${dns_resolv_file} if it was previously modified by this script 
fi
cp ${dns_resolv_file} ${dns_resolv_file}.orig
awk -v dnsvar=${bridgeip} 'done != 1 && /^nameserver.*$/ { print "nameserver "dnsvar"\n"; done=1 } 1' ${dns_resolv_file} > ${dns_config_file_tmp}
mv ${dns_config_file_tmp} ${dns_resolv_file}
#Add testvirt.net as domain suffix
sed -irn "s/^search/search ${dns_domain_forward}/" ${dns_resolv_file}
#Add 192.168.123.1 as forwarder
get_nameservers=`cat ${dns_resolv_file} | grep -iE "^nameserver" | awk '{print $NF}'`
nameservers_array=$(echo -e ${get_nameservers})
unset forwarders_array
declare -a forwarders_array=""
for single_nameserver in ${nameservers_array[@]};do
	forwarders_array+=(${single_nameserver}\;)
done	
sed -irn "/^ *forwarders/s/forwarders.*$/forwarders { `echo -e ${forwarders_array[@]}` };/" ${dns_config_file}
#Insert script signature to the end of ${dns_config_file} and ${dns_resolv_file}
echo -e "#$0" >> ${dns_config_file}
echo -e "#$0" >> ${dns_resolv_file}

echo "" | tee -a ${setup_log_file}
echo "****** content of /etc/resolv.conf ****" | tee -a ${setup_log_file}
cat /etc/resolv.conf | tee -a ${setup_log_file}
echo "------------------------------------" | tee -a ${setup_log_file}
echo "" | tee -a ${setup_log_file}

#Start named service. Quit if failed.
dns_service_name="named"
get_os_installed_release=`lsb_release -r | grep -oE "[[:digit:]]{2}"`
os_installed_release=$(echo ${get_os_installed_release})
get_os_installed_sp=`cat /etc/os-release | grep "SUSE Linux Enterprise Server" | grep -oE "SP[0-9]{1,}" | grep -oE "[0-9]{1,}"`
os_installed_sp=$(echo ${get_os_installed_sp})
if [[ ${os_installed_release} -gt '11' ]];then
        systemctl enable ${dns_service_name}
        systemctl restart ${dns_service_name}
        dns_service_failed=$(echo $?)
        systemctl status ${dns_service_name} | tee -a ${setup_log_file}
else
        service ${dns_service_name} restart
        dns_service_failed=$(echo $?)
        service ${dns_service_name} status | tee -a ${setup_log_file}
fi
if [[ ${dns_service_failed} -ne 0 ]];then
        echo -e "DNS service did not start up as normal. Please investigate.\n" | tee -a ${setup_log_file}
        echo -e "DNS resolver file content:\n" | tee -a ${setup_log_file}
        cat ${dns_resolv_file} | tee -a ${setup_log_file}
        echo -e "NAMED service file content:\n" | tee -a ${setup_log_file}
        cat ${dns_config_file} | tee -a ${setup_log_file}
        exit 1
fi

#Generate ssh key and set it as IdentityFile in /etc/ssh/ssh_config
ssh_key_pass=`/usr/share/qa/virtautolib/lib/get-settings.sh vm.pass`
ssh_key_path="/var/${dns_domain_forward}/.ssh"
ssh_config_file="/etc/ssh/ssh_config"
ssh_config_temp="/etc/ssh/ssh_config.temp"
cat ${ssh_config_file} | grep "#$0"
if [ $? -eq 0 ];then
        mv ${ssh_config_file}.orig ${ssh_config_file} #Restore ${ssh_config_file} if it was previously modified by this script
fi
cp ${ssh_config_file} ${ssh_config_file}.orig
#Remove already existed key pairs
if [ -e ${ssh_key_path}/id_rsa ];then
        rm -f ${ssh_key_path}/id_rsa
        rm -f ${ssh_key_path}/id_rsa.pub
fi
rm -f -r ${ssh_key_path}
mkdir -p ${ssh_key_path}
#Generate new key pairs and write private key path into ${ssh_config_file}
ssh-keygen -t rsa -f ${ssh_key_path}/id_rsa -q -P "" | tee -a ${setup_log_file}
awk -v sshvar="${ssh_key_path}/id_rsa" 'done != 1 && /^#.*IdentityFile.*$/ { print "IdentityFile "sshvar"\n"; done=1 } 1' ${ssh_config_file} > ${ssh_config_temp}
mv ${ssh_config_temp} ${ssh_config_file}
#Insert script signature to the end of ${ssh_config_file}
echo -e "#$0" >> ${ssh_config_file}

#Wait another 120s before start attempting ping vm guest
#in order to avoid unnecessary failure
for i in `seq 12`;do
	echo -e "Please be patient. Will attempt ping shortly.\n"
	sleep 10s
	echo -e "$((120 - $i * 10)) seconds remaining.\n"
done

echo "" | tee -a ${setup_log_file}
echo "# virsh list --all" | tee -a ${setup_log_file}
virsh list --all | tee -a ${setup_log_file}
ehco "" | tee -a ${setup_log_file}

ehco "" | tee -a ${setup_log_file}
echo "the new /etc/named.conf after modified: "  | tee -a ${setup_log_file}
echo "cat /etc/named.conf" | tee -a ${setup_log_file}
echo "---------" | tee -a ${setup_log_file}
cat /etc/named.conf | tee -a ${setup_log_file}
echo "---------" | tee -a ${setup_log_file}
echo "" | tee -a ${setup_log_file}

#Try to ping all vm guests by using their dns names. Quit if any failure. 
sleep_time=180
sleep_count=0
failed_count=0
unset vmguest_ping_failed
declare -a vmguest_ping_failed=""
while [ ${sleep_count} -le ${sleep_time} ];do
	echo -e "Try $((${sleep_count}/10 + 1)) time(s) ping\n" | tee -a ${setup_log_file}
	vmguest_index=0
	#Ping each vm guest by using its dns name and store result.
	for vmguest in ${vm_guestnames_array[@]};do
		ping -c 1 ${vmguest} | tee -a ${setup_log_file}
		vmguest_ping_failed[${vmguest_index}]=`echo $?`
                vmguest_index=$((${vmguest_index} + 1))
	done
	failed_count=0
	vmguest_index=0
	#Iterate vmguest_ping_failed to check whether ping to each vm guest succeeded.
	for vmguest in ${vm_guestnames_array[@]};do
		if [[ ${vmguest_ping_failed[${vmguest_index}]} -ne 0 ]];then
        		echo -e "Connection to ${vmguest} using its dns name failed !\n" | tee -a ${setup_log_file}
                	failed_count=$((${failed_count} + 1))
		else
        		echo -e "Connection to ${vmguest} using its dns name succeeded !\n" | tee -a ${setup_log_file}
		fi
		vmguest_index=$((${vmguest_index} + 1))
	done
	#If ping to all vm guests by using their dns names succeeded, terminate while loop and proceed. 
	if [[ ${failed_count} -eq 0 ]];then
        	echo -e "Connection to all virtual machines by using DNS names is working now.\n" | tee -a ${setup_log_file}
        	break
	fi
	sleep_count=$((${sleep_count} + 10))
	sleep 10s
done

#Copy host ssh public key to all vm guests. Quit if any failure.
sleep_time=180
sleep_count=0
failed_count=0
unset vmguest_sshcopyid_failed
declare -a vmguest_sshcopyid_failed=""
if [[ ${failed_count} -gt 0 ]];then
        echo -e "DNS service does not work for at least one vm. Please pay attention !\n" | tee -a ${setup_log_file}
        exit 1
else
	echo -e "DNS service works for al vm guests !\n" | tee -a ${setup_log_file}
	while [ ${sleep_count} -le ${sleep_time} ];do
		echo -e "Try $((${sleep_count}/10 + 1)) time(s) ssh-copy-id\n" | tee -a ${setup_log_file}
        	vmguest_index=0
		#Use sshpass to copy public key into vm guest for the first time and store results
		for vmguest in ${vm_guestnames_array[@]};do
			if [[ ${os_installed_release} -ge '15' ]] || [[ ${os_installed_release} -ge '12' && ${os_installed_sp} -ge '2' ]];then
				sshpass -p ${ssh_key_pass} ssh-copy-id -i ${ssh_key_path}/id_rsa.pub -f root@${vmguest}
			else
				sshpass -p ${ssh_key_pass} ssh-copy-id -i ${ssh_key_path}/id_rsa.pub root@${vmguest}
			fi
			vmguest_sshcopyid_failed[${vmguest_index}]=`echo $?`
                	vmguest_index=$((${vmguest_index} + 1))
		done
		failed_count=0
                vmguest_index=0
		#Iterate vmguest_sshcopyid_failed to check whether ssh-copy-id succeeded.
        	for vmguest in ${vm_guestnames_array[@]};do
                	if [[ ${vmguest_sshcopyid_failed[${vmguest_index}]} -ne 0 ]];then
                        	echo -e "SSH COPY ID to ${vmguest} using its dns name failed !\n" | tee -a ${setup_log_file}
                        	failed_count=$((${failed_count} + 1))
                	else
                        	echo -e "SSH COPY ID to ${vmguest} using its dns name succeeded !\n" | tee -a ${setup_log_file}
                	fi
                	vmguest_index=$((${vmguest_index} + 1))
        	done
		#If ssh-copy-id succeeded for all vm guests, terminate while loop and proceed.
        	if [[ ${failed_count} -eq 0 ]];then
                	echo -e "SSH COPY ID to all virtual machines by using DNS names is working now.\n" | tee -a ${setup_log_file}
                	break
        	fi
	        sleep_count=$((${sleep_count} + 10))
		sleep 10s
	done
fi

#Verify whether connecting to all vm guests by using ssh without inputting login password works. Quit if any failure.
#So test owner can query vm guest directly on host by using "ssh root@vmguest query_cmd".
failed_count=0
if [[ ${failed_count} -gt 0 ]];then
        echo -e "Failed to ssh-copy-id for at least one vm. Please pay attention !\n" | tee -a ${setup_log_file}
        exit 1
else
        #Show the associated ssh key that is being used
	eval `ssh-agent -t 86400 -s`
	ssh-add -t 86400 ${ssh_key_path}/id_rsa
	ssh-add -L
	echo -e "Succeeded ssh-copy-id to all virtual machines by using DNS names.\n" | tee -a ${setup_log_file}
	for vmguest in ${vm_guestnames_array[@]};do
       		echo -e "ssh root@${vmguest} whoami" | tee -a ${setup_log_file}
		ssh root@${vmguest} whoami
		if [[ $? -ne 0 ]];then
			echo -e "NoPassword SSH connection to ${vmguest} failed !\n" | tee -a ${setup_log_file}
                	failed_count=$((${failed_count} + 1))
		else
			echo -e "NoPassword SSH connection to ${vmguest} succeeded !\n" | tee -a ${setup_log_file}
        	fi
	done
fi

#Quit if any vm guest can not be reached by using ssh without inputting login password, otherwise the script comes to the end and finishes successfully
if [[ ${failed_count} -gt 0 ]];then
        echo -e "connecting to vm guests by using ssh without inputting login password does not work for at least one vm. Please pay attention !\n" | tee -a ${setup_log_file}
        exit 1
else
        echo -e "connecting to all vm guests by using ssh without inputting login password is working now.\n" | tee -a ${setup_log_file}
fi
chmod 777 ${setup_log_file}
exit 0
