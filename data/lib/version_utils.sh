#!/bin/bash

set -e

#########################################################################
###
### Returns 0 if script runs on Tumbleweed
###
### Example:
### isTumbleweed
### echo $?

isTumbleweed(){
   if [ ! -f /etc/os-release ]; then
      return 1
   fi
   if (grep -i -q "openSUSE Tumbleweed" /etc/os-release); then
      return 0
   fi
   return 1
}

#########################################################################
###
### Returns 0 if script runs on Leap15
###
### Example:
### isLeap15
### echo $?

isLeap15(){
   if [ ! -f /etc/os-release ]; then
      return 1
   fi
   if (grep -i -q "openSUSE Leap 15" /etc/os-release); then
      return 0
   fi
   return 1
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
