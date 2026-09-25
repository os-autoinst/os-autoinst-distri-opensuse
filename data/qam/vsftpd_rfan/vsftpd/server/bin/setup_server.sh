#! /bin/bash
# RCF = return code of function;
suite="/tmp/vsftpd/server"
# 0= OK
# 1= NOT Show stopper - like user exists
# 2= Wrong function call

# exit = exit codes
# 1= something failed - no reason to continue
#

#### DECLARATION OF FUNCTIONS #{{{
function report() #{{{
# accepts two arguments $1=I|W|E $2=MSG
{
	PRINT_TYPE=( INFO WARN ERROR )
	if [ $1 = 'I' ]; then
		echo -e ""
		echo -e "${PRINT_TYPE[0]}: $2"
	elif [ $1 = 'W' ]; then
		echo -e "\n"
		echo -e "${PRINT_TYPE[1]}: $2"
	elif [ $1 = 'E' ]; then
		echo -e "\n"
		echo -e "\033[31m${PRINT_TYPE[2]}\e[0m: $2"
	else
		echo -e ""
		echo "${PRINT_TYPE[2]}: Not $PRINT_TYPE"; exit 1
	fi
	return $RCF
} #}}}

function has_ssl() #{{{
# accepts one parameter $1=certificate.pem
{
	RCF="0"
	report "I" "Copy certificate to right place"
	if ! [ -d /etc/vsftpd ];then mkdir /etc/vsftpd;fi
	[ $? -eq 0 ] || RCF=1
	install -D -m 0600 $suite/data/$1 /etc/vsftpd/vsftpd.pem
	[ $? -eq 0 ] || RCF=1
	return $RCF
} #}}}

function start_stop() #{{{
# accepts one parameter $1=start | stop, bonus PID check
{
	RCF="0"
	if [ $1 = 'start' ]; then
		report "I" "Starting vsftpd service"
		service vsftpd start
		[ $? -eq 0 ] || { report "E" "Vsftpd process not started"; exit 1; }
		report "I" "Check if the vsftpd sevice is running"
		sleep 1
		pgrep vsftpd
		[ $? -eq 0 ] || { report "E" "Vsftpd process not found"; exit 1; }
	elif [ $1 = 'stop' ]; then
		report "I" "Stopping ftp service"
		service vsftpd stop
		[ $? -eq 0 ] || { report "E" "Vsftpd process not stopped"; exit 1; }
		report "I" "Check if the vsftpd sevice is running"
		pgrep vsftpd
		[ $? -ne 0 ] || { report "E" "vsftpd process found - should be stopped"; exit 1; }
	else
		report "E" "Wrong parameter: start_stop"; RCF=2
	fi
	return $RCF
} #}}}

function copy_config() #{{{
# accepts one argument $1=vsftpd.conf
{
	RCF="0"
	report "I" "Overwrite the configuration file"
	cp -a $suite/data/$1 /etc/vsftpd.conf
	[ $? -eq 0 ] || { report "E" "copy file \"$1\" failed"; exit 1; }
	return $RCF
} #}}}

function copy_test_data() #{{{
# accepts as arguments $1=owner:group $2=777 permissions $3=PATH_where_to_copy and rest are file names $4=file1 $5=file2
{
RCF="0"
local USR_GRP="$1"
local PERM="$2"
local PLACE="$3"
shift 3
local FILES="$*"
report "I" "Uploading test data"
for i in $FILES; do
	pushd $suite/data/ && cp -a $i /srv/ftp/$PLACE
	[ $? -eq 0 ] || { RCF=1; report "E" "copy file \"$i\" failed"; }
	chown $USR_GRP /srv/ftp/$PLACE/$i
	[ $? -eq 0 ] || { RCF=1; report "E" "setting owner for \"$i\" failed"; }
	chmod $PERM /srv/ftp/$PLACE/$i
	[ $? -eq 0 ] || { RCF=1; report "E" "setting permissions for \"$i\" failed"; }
	popd
done
return $RCF
} #}}}

function create_user() #{{{
# accepts 2 arguments $1=type local|virtual $2=username
# virtual users are suspended due to missing userdb.so for now
# or different way has to be found
{
	RCF="0"
	if [ $1 = 'local' ];then
		report "I" "Create $2 user"
		useradd -d /srv/ftp/users/$2 -s /bin/bash $2
		[ $? -eq 0 ] || RCF=1
	elif [ $1 = 'virtual' ];then
		report "E" "Virtual users not working now"
		RCF=1
		#report "I" "Create $1 user"
		####
		[ $? -eq 0 ] || RCF=1
	else
		report "E" "Not valid option in $FUNCNAME"; RCF=2
	fi

	#####
	#echo "Adding nologin to /etc/shells"
	#echo "/sbin/nologin" >> /etc/shells
	#[ $? -eq 0 ] || RCF=7
	return $RCF
} #}}}

function set_password() #{{{
# accepts 2 argument $1=user $2=password
{
	RCF="0"
	report "I" "Setting user $2 password"
	echo "$1:$2" | chpasswd
	[ $? -eq 0 ] || { report "E" "Password not set"; exit 1; }
	return $RCF
} #}}}

function create_users_dirs () #{{{
# accepts 2 arguments $1=type local|virtual $2 user
# virtual users are suspended due to missing userdb.so for now
# or different way has to be found
{
	RCF="0"
	local ACTION=$1
	[ -z $ACTION ] && ACTION=none
	if [ $1 = 'local' ]; then
		report "I" "Create user $2 dir"
		mkdir -p /srv/ftp/users/$2
		[ $? -eq 0 ] || RCF=1
	elif [ $1 = 'virtual' ]; then
		report "E" "Virtual users not working now"
		RCF=1
	else
		report "E" "Not valid option in $FUNCNAME";	RCF=2
	fi
	return $RCF
} #}}}

function user_dir_permissions() #{{{
# accepts 2 arguments $1=type local|virtual $2 user
# virtual users are suspended due to missing userdb.so for now
# or different way has to be found
{
	RCF="0"
	if [ $1 = 'local' ]; then
		report "I" "Chown ftp dir for user $2"
		chown -R $2:users /srv/ftp/users/$2
		[ $? -eq 0 ] || { report "E" "Chown of a local dir failed for user $2"; exit 1; }
	elif [ $1 = 'virtual' ]; then
		report "E" "Virtual users not working now"
		RCF=1
	else
		report "E" "Not valid option in $FUNCNAME"; RCF=2
	fi
	return $RCF
} #}}}

function set_firewall() #{{{
# accepts numeric arguments or ranges e.g. $1=20 $2=21 $3=65000:65500
{
	RCF="0"
	for i in $@; do
		local PORTNUM="$i"
		local PORTRANGE_VALIDATOR="^[0-9]+:[0-9]+$"
		if [[ $PORTNUM -eq "$PORTNUM"  ]] 2>/dev/null; then
			report "I" "Enabling TCP port $i on firewall"
            if [ -e /usr/sbin/firewalld ]; then
                firewall-cmd --add-port=$i/tcp
            else
			    yast2 firewall services add tcpport=$i zone=EXT > /dev/null
            fi
		[ $? -eq 0 ] || { report "E" "firewall setup failed for port $i"; exit 1; }
		elif [[ $PORTNUM =~ $PORTRANGE_VALIDATOR  ]]; then
			report "I" "Enabling range of TCP ports $i on firewall"
			yast2 firewall services add tcpport=$i zone=EXT > /dev/null
		[ $? -eq 0 ] || { report "E" "firewall setup failed for port range $i"; exit 1; }
		else
			report "E" "Not a number or range in $FUNCNAME"; RCF=2
		fi
	done
	return $RCF
} #}}}

function prepare_anon_dir() #{{{
# accepts 0 arguments
{
	RCF="0"
	if ! [ -d /srv/ftp/anon  ]; then
		report "I" "Preparing anon dir and setting permissions"
		mkdir -p /srv/ftp/anon/x;
		[ $? -eq 0  ] || RCF=1
		chown -R ftp:ftp /srv/ftp/anon
		[ $? -eq 0  ] || RCF=1
		chmod ugo-w /srv/ftp/anon
		[ $? -eq 0  ] || RCF=1
	fi
	return $RCF
} #}}}

function clear_ftpdata_dir() #{{{
# accepts 1 argument $1=anon or user
{
	RCF="0"
	report "I" "Clearing anon directory"
	[ -z $1 ] && report "E" "Not valid option in $FUNCNAME"; RCF=2; return $RCF
	if [ $1 = "anon" ];then
		rm /srv/ftp/anon/x/*.file
	else
		rm /srv/ftp/users/$1/*.file
	fi
	return $RCF
} #}}}

#}}}
