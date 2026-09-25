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
		cat << EOF > /srv/ftp/users/testerchroot/$i
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

#### Main ####
echo "File $0"
source $suite/bin/setup_server.sh
start_stop stop
copy_config 07_NOSSL_listdirs_valid_users_chroot.conf
start_stop start
# user which will be forbidden(wrong chroot perms)
create_user local tester
set_password tester Test_pass1
create_users_dirs local tester
user_dir_permissions local tester
#set_firewall 21 22
echo "RC: $RC"
exit $RC
