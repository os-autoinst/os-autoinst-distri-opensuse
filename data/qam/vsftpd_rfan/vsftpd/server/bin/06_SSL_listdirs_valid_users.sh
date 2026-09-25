#!/bin/bash
#### VARIABLES ##### #{{{
suite="/tmp/vsftpd/server"
#fake term variable for yast2 - it gives an error if TERM not set
export TERM=linux
RC=0
#}}}

#### PREPARATION ####
function create_some_files() #{{{
# just create files to list them
{
report "I" "Creating some files for $1"
local RC=0
local FTPUSER="$1"
shift
for i in $@;do
	if [ $FTPUSER = 'local' ]; then
		cat << EOF > /srv/ftp/users/tester/$i
This is file $i.
EOF
		[ $? -eq 0 ] || { RC=1; report "E" "create file \"$i\" failed"; }
	elif [ $FTPUSER = 'anonymous' ]; then
		cat << EOF > /srv/ftp/anon/$i
EOF
		[ $? -eq 0 ] || { RC=1; report "E" "create file \"$i\" failed"; }
	fi
done
return $RC
} #}}}

function create_x_userdir () #{{{
{
report "I" "Creating dir x at user folder"
[ -d /srv/ftp/users/tester/x ] || mkdir /srv/ftp/users/tester/x
} #}}}

#### Main ####
echo "File $0"
source $suite/bin/setup_server.sh
start_stop stop
has_ssl vsftpd.pem
copy_config 06_SSL_listdirs_valid_users.conf
start_stop start
create_user local tester
set_password tester Test_pass1
create_users_dirs local tester
user_dir_permissions local tester
create_some_files local file1 file2 file3
create_x_userdir tester
copy_test_data tester:users 755 users/tester test_binary.file test_text.file
prepare_anon_dir
copy_test_data ftp:ftp 755 anon/x test_binary.file test_text.file
create_some_files anonymous file1 file2 file3
#set_firewall 21 22
echo "RC: $RC"
exit $RC
