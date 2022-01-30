#!/bin/bash
###############################################################################
# (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of version 2 the GNU General Public License as
#   published by the Free Software Foundation.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################
# 
# PURPOSE:
# Test all the allowed ciphers for ipsec
DATE=`date +%Y%m%d-%H%M%S`
LOG=ccc-ipsec-eval-weak.log

function check_connection {
	ipsec start 2>> $LOG >> $LOG
	sleep 1
	echo "ipsec up ikev2suse" >> $LOG
	ipsec up ikev2suse 2>> $LOG >> $LOG
	sleep 1
	ping -W1 -c1 192.168.250.1 > /dev/null
	if [ $? != 0 ]; then
		echo "Error 1"
		ipsec down ikev2suse >& /dev/null
		ipsec stop >& /dev/null
		return
	fi
	ipsec_sa_state=$(ipsec statusall | grep 'Security Associations (1 up')
	ipsec statusall | grep 'Security Associations' -A 5 >> $LOG
	if [ $ipsec_sa_state -gt 0 ]; then
		echo "Okay"
	else
		echo "Error"
	fi
	ipsec down ikev2suse >& /dev/null
	ipsec stop >& /dev/null

	echo >> $LOG
}


#ensure valid ciphers are used
sed -i -e "s/esp=.*/esp=aes128-sha512-modp2048/" /etc/ipsec.conf
sed -i -e "s/ike=.*/ike=aes256ctr-sha256-modp2048}/" /etc/ipsec.conf

sed -i -e "s/keyexchange=.*/keyexchange=ikev1/" /etc/ipsec.conf

echo -n "IKEv1: "
echo "---------------------------------------------------------" >> $LOG
echo "IKE version: v1" >> $LOG
check_connection 

weak_algo=3des-sha256-ecp224bp
echo -n "esp $weak_algo: "
echo "---------------------------------------------------------" >> $LOG
echo "esp: $weak_algo" >> $LOG
sed -i -e "s/keyexchange=.*/keyexchange=ikev2/" /etc/ipsec.conf
sed -i -e "s/esp=.*/esp=3des-sha256-ecp224bp!/" /etc/ipsec.conf
check_connection 
