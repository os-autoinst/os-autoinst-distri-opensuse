#!/bin/bash

# Specify the network interface name
interface="eth0"

# Create the network profile file
profile_file="/etc/sysconfig/network/ifcfg-$interface"
touch $profile_file

# Add configuration to the network profile file
echo "BOOTPROTO='dhcp'" >> $profile_file
echo "STARTMODE='auto'" >> $profile_file

# Restart the network service to apply the changes
systemctl restart wicked.service
