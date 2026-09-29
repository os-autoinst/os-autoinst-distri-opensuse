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

function create_x_userdir () #{{{
# accepts one argument $1=user
{
report "I" "Creating dir x at user folder"
[ -d /srv/ftp/users/$1/files ] || mkdir /srv/ftp/users/$1/files
[ -d /srv/ftp/users/$1/files/x ] || mkdir /srv/ftp/users/$1/files/x
} #}}}

function set_chroot_perms () #{{{
{
	report "I" "Removing write perms on chroot folder for user $1"
	chmod ugo-w /srv/ftp/users/$1
} #}}}

#### Main ####
echo "File $0"
source $suite/bin/setup_server.sh
start_stop stop
copy_config 07_NOSSL_listdirs_valid_users_chroot.conf
start_stop start
create_user local testerchroot
set_password testerchroot Test_pass1
create_users_dirs local testerchroot
user_dir_permissions local testerchroot
create_some_files local file1 file2 file3
create_x_userdir testerchroot
set_chroot_perms testerchroot
copy_test_data testerchroot:users 755 users/testerchroot/files/x test_binary.file test_text.file
prepare_anon_dir
create_some_files anonymous file1 file2 file3
create_user local tester
# user which will be forbidden(wrong chroot perms)
set_password tester Test_pass1
create_users_dirs local tester
user_dir_permissions local tester
#set_firewall 21 22
echo "RC: $RC"
exit $RC
