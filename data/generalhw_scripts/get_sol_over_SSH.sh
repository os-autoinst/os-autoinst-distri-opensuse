#!/bin/sh -e

# Call the right script on the system where the serial is connected to

# Get parameters
# IP of the system where the serial adaptor is connected to
remoteIP=$1
# Script to run on this system to grab the serial. You may need to mount the openQA NFS share on /var/lib/openqa/share
script=${2:-/var/lib/openqa/share/tests/opensuse/data/generalhw_scripts/get_sol_ttyUSB0.sh}

# Execute on target (with $user)
user=root # $(whoami)
ssh $user@$remoteIP $script
