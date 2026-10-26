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
prepare_anon_dir
clear_ftpdata_dir anon
copy_config 02_SSL_anon_only_ro.conf
copy_test_data ftp:ftp 755 anon/x test_binary.file test_text.file
start_stop start
#create_user local tester
#set_password tester testpass
#create_users_dirs local tester
#user_dir_permission
#set_firewall 21 22
echo "RC: $RC"
exit $RC
