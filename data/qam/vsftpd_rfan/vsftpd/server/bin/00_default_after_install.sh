#!/bin/bash
#### VARIABLES ##### #{{{
suite="/tmp/vsftpd/server"
#fake term variable for yast2 - it gives an error if TERM not set
export TERM=linux
RC=0
#}}}

#### Main ####
echo "File $0"
source $suite/bin/setup_server.sh
start_stop stop
start_stop start

echo -e "\nChecking if vsftpd is listening on port:\n"
ss -lnpt | grep vsftpd
[ $? -eq 0 ] || { RC=1; report "E" "vsftpd is not listening on any port"; }

echo "RC: $RC"
exit $RC

