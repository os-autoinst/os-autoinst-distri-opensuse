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
copy_config 04_NOSSL_local_users_only_ro.conf
start_stop start
create_user local tester
set_password tester Test_pass1
create_users_dirs local tester
user_dir_permissions local tester
copy_test_data tester:users 755 users/tester test_binary.file test_text.file
#set_firewall 21 22
echo "RC: $RC"
exit $RC
