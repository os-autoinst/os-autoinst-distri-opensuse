# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash


isVM(){
 local GUESTNAME=""
 local GUESTNO=""

   if [ ! -e /proc/sysinfo ] ; then
    echo "Cannot access /proc/sysinfo" >&1
    exit 1
   fi

   GUESTNAME="$(cat /proc/sysinfo | grep -i VM00.Name | sed 's/^.*:[[:space:]]*//g;s/[[:space:]]//g' | tr '[a-z]' '[A-Z]')"

   if [ -z "$GUESTNAME" ];then
    return 1
   fi
   if [ -n "$GUESTNAME" ];then
      load_vmcp
      return 0
   fi
   return 1
}

#######################################################
###
### common.sh :: s390_config_check()
###
### Check if s390 config is set
###
### Example:
### s390_config_check S390_CONFIG_DASD
###

s390_config_check(){
        local config=$1
        local config_line=$(env | grep "$config=")

        if [ $? -ne 0 ]; then
                assert_warn fail pass "Config option $config not defined"
                exit 1
        else
                value=$(echo $config_line | awk -F = '{print $2}')
                echo "USING CONFIG: $config=$value"
        fi
}

#########################################################################
### HINT: With SLES15 the /etc/SuSE-release file was abandoned
###                            os-release is now used
###
### Returns 0 if script runs on SLES15
###
### Example:
### isSles15
### echo $?

isSles15(){
   if [ ! -f /etc/os-release ]; then
      return 1
   fi
   if (grep -i -q "SUSE Linux Enterprise Server 15" /etc/os-release); then
      return 0
   fi
   return 1
}

#######################################################
###
### Return path to tool if $objdir is set
###
### Example:
### s390_get_tool_path dasdfmt
###

s390_get_tool_path(){
        if [ "$objdir" == "" ]; then
                echo $1
        else
                echo "$objdir/$1"
        fi
}

isVconfigOrIP()
{
if [ -f "/sbin/vconfig" ]
then
    #echo "use ifconfig"
    #IFCONFIG="$(ls /sbin/ | grep -w ifconfig)"
    #echo $IFCONFIG
    return 0
elif [ -f "/sbin/ip" ]
then
     #echo "use ip"
     #IFCONFIG="$(ls /sbin/ | grep -w ip)"
     #echo $IFCONFIG
     return 1
fi
}

isIfconfigOrIP()
{
local IFCONFIG
if [ -f "/sbin/ifconfig" ]
then
    #echo "use ifconfig"
    #IFCONFIG="$(ls /sbin/ | grep -w ifconfig)"
    #echo $IFCONFIG
    return 0
elif [ -f "/sbin/ip" ]
then
     #echo "use ip"
     #IFCONFIG="$(ls /sbin/ | grep -w ip)"
     #echo $IFCONFIG
     return 1
fi
}

load_vmcp(){
 local GUESTNAME=""

   if [ ! -e /proc/sysinfo ] ; then
    echo "Cannot access /proc/sysinfo" >&1
    exit 1
   fi

   GUESTNAME="$(cat /proc/sysinfo | grep -i VM00.Name | sed 's/^.*:[[:space:]]*//g;s/[[:space:]]//g' | tr '[a-z]' '[A-Z]')"

   if [ -n "$GUESTNAME" ];then
        `vmcp q cpus > /dev/null 2>&1`
        if [ $? -ne 0 ];then
         modprobe vmcp >/dev/null 2>&1
         echo "Module vmcp loaded"
        fi
        return 0
   fi
   return 1
}
