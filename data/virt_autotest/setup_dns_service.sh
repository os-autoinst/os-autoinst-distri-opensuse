#!/bin/bash

source /usr/share/qa/qa_test_virtualization/shared/standalone
bridgeif="br123"
bridgeip="192.168.123.1";
dns_domain_forward="testvirt.net";
dns_domain_reverse="123.168.192";
dhcpd_lease_file="/var/lib/dhcp/db/dhcpd.leases"
setup_log_file="/var/log/virt_dns_setup.log"

if [ -e ${setup_log_file} ];then
	rm -f ${setup_log_file}
fi

zypper_cmd="zypper --non-interactive in lsb-release bridge-utils bind bind-chrootenv bind-utils"
echo -e "${zypper_cmd} will be executed\n" | tee -a ${setup_log_file}
${zypper_cmd}

#Write {vmguestname => vmipaddress} key => value pairs into vm_guestnames_array and vm_hash_forward arrays
#The dictionary will be used to fill out the forward dns zone file
#Write {vmipaddress last part => vmguestname} key => value pairs into vm_guestnames_array and vm_hash_reverse arrays
#The dictionary will be used to fill out the reverse dns zone file
unset vm_hash_forward_ipaddr
unset vm_hash_reverse_ipaddr
declare -a vm_hash_forward_ipaddr=""
declare -a vm_hash_reverse_ipaddr=""
get_vm_guestnames_inactive=`virsh list --inactive | grep sles | awk '{print $2}'`
vm_guestnames_inactive_array=$(echo -e ${get_vm_guestnames_inactive})
get_vm_guestnames=`virsh list  --all | grep sles | awk '{print $2}'`
vm_guestnames_array=$(echo -e ${get_vm_guestnames})
get_vm_macaddress=""
vm_macaddresses_array=""
get_vm_ipaddress=""
vm_ipaddress="";
vm_ipaddress_lastpart=""
vm_hash_index=0
vmguest=""

vmguest_failed=0
for vmguest in ${vm_guestnames_array[@]};do
        echo -e ${vm_guestnames_inactive_array[*]} | grep ${vmguest}
        if [[ `echo $?` -eq 0 ]];then
		virsh start ${vmguest}
		vmguest_failed=$((${vmguest_failed} | $(echo $?)))
        else
            	virsh reboot ${vmguest}
	    	vmguest_failed=$((${vmguest_failed} | $(echo $?)))
        fi
done
if [[ ${vmguest_failed} -ne 0 ]];then
	echo -e "At least one virtual machine can not be started up as normal. Please investigate.\n" | tee -a ${setup_log_file}	
	exit 1
fi

sleep 30s
echo -e "Virtual machines ${vm_guestnames_array[@]} have already been refreshed\n" | tee -a ${setup_log_file}

for vmguest in ${vm_guestnames_array[@]};do
        get_vm_macaddress=`virsh domiflist --domain ${vmguest} | grep -oE "([0-9|a-z]{2}:){5}[0-9|a-z]{2}"`
        vm_macaddresses_array[${vm_hash_index}]=$(echo -e ${get_vm_macaddress})
        get_vm_ipaddress=`tac $dhcpd_lease_file | awk '!($0 in S) {print; S[$0]}' | tac | grep -iE "${vm_macaddresses_array[${vm_hash_index}]}" -B8 | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | tail -1`
        vm_ipaddress=$(echo -e ${get_vm_ipaddress})
        vm_ipaddress_lastpart=$(echo -e ${vm_ipaddress} | grep -Eo "[0-9]{1,3}$")
        vm_hash_forward_ipaddr[${vm_hash_index}]=${vm_ipaddress}
        vm_hash_reverse_ipaddr[${vm_hash_index}]=${vm_ipaddress_lastpart}
        vm_hash_index=$(($vm_hash_index + 1))
        echo -e ${vm_hash_forward_ipaddr[${vm_hash_index}]}
done

dns_forward_zone_file="/var/lib/named/${dns_domain_forward}.zone"
dns_reverse_zone_file="/var/lib/named/${dns_domain_reverse}.zone"
dns_record=""
dns_records_forward=""
dns_records_reverse=""
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

ns                             IN      A       192.168.123.1
;;
$(echo -e ${dns_records_forward})
;;
; Mail server MX record
@            IN      MX      10      mailmaster.$dns_domain_forward.
mailmaster   IN      A       192.168.123.1
EOF

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
cp ${dns_resolv_file} ${dns_resolv_file}.orig
awk -v dnsvar=${bridgeip} 'done != 1 && /^nameserver.*$/ { print "nameserver "dnsvar"\n"; done=1 } 1' ${dns_resolv_file} > ${dns_config_file_tmp}
mv ${dns_config_file_tmp} ${dns_resolv_file}
#Add testvirt.net as domain suffix
sed -irn "/^search/ s/$/ ${dns_domain_forward}/" ${dns_resolv_file}
#Add 192.168.123.1 as forwarder
get_nameservers=`cat ${dns_resolv_file} | grep -iE "^nameserver" | awk '{print $NF}'`
nameservers_array=$(echo -e ${get_nameservers})
unset forwarders_array
declare -a forwarders_array=""
for single_nameserver in ${nameservers_array[@]};do
	forwarders_array+=(${single_nameserver}\;)
done	
sed -irn "s/forwarders.*$/forwarders { `echo -e ${forwarders_array[@]}` };/" ${dns_config_file}

#Start named service. Quit if failed.
dns_service_name="named"
get_os_installed_release=`lsb_release -r | grep -oE "[[:digit:]]{2}"`
os_installed_release=$(echo ${get_os_installed_release})
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

#Ping vm machines one by one. Quit if any failure.
sleep 45s
failed_count=0
for vmguest in ${vm_guestnames_array[@]};do
        ping -c 5 ${vmguest}
	if [[ `echo $?` -ne 0 ]];then
		echo -e "Connection to ${vmguest} using its dns name failed !\n" | tee -a ${setup_log_file}
	    	failed_count=$((${failed_count} + 1))
        else
            	echo -e "Connection to ${vmguest} using its dns name succeeded !\n" | tee -a ${setup_log_file}
        fi
done

chmod 777 ${setup_log_file}
if [[ ${failed_count} -gt 0 ]];then
	echo -e "DNS service does not work for at least one vm. Please pay attention !\n" | tee -a ${setup_log_file}
	exit 1
else
	echo -e "SSH Connection to all virtual machines by using DNS names is working now.\n" | tee -a ${setup_log_file}
fi
exit 0
