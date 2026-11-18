#! /bin/bash
set -e
#### VARIABLES #{{{

SCENUM=1

#}}}

suite="/tmp/vsftpd"
#source control-functions.sh

echo "SERVER: $SERVER"
# allow ssh connect from client to server for filelist comparison
#ssh_access root client root server

#### TESTS # {{{
	echo "Scenario-$SCENUM Default configuration" && SCENUM=$(($SCENUM+1))
	ssh $SERVER $suite/server/bin/00_default_after_install.sh

# don't test SSL due to https://bugzilla.suse.com/show_bug.cgi?id=1116571
for i in "NOSSL" "SSL"; do
#for i in "NOSSL"; do

	echo "Scenario-$SCENUM $i vsftpd configuration" && SCENUM=$(($SCENUM+1))
	echo "Test vsftpd service with $i local users only ro"
	ssh $SERVER $suite/server/bin/01_${i}_local_users_only_ro.sh

	echo "$i curl used to UP and DWNLD files - local users only ro"
	ssh $CLIENT $suite/client/bin/01_${i}_local_users_only.sh $SERVER ro

	echo "Test vsftpd service with $i - local users only rw"
	ssh $SERVER $suite/server/bin/02_${i}_local_users_only_rw.sh

	echo "$i curl used to UP and DWNLD files - local users only rw"
	ssh $CLIENT $suite/client/bin/01_${i}_local_users_only.sh $SERVER rw

	echo "Test vsftpd service with $i - invalid users only"
	ssh $SERVER $suite/server/bin/05_${i}_invalid_users_only.sh

	echo "$i curl used to UP and DWNLD files - invalid users only"
	ssh $CLIENT $suite/client/bin/03_${i}_invalid_users_only.sh $SERVER rw

	echo "Test vsftpd service with $i listdirs valid users only"
	ssh $SERVER $suite/server/bin/06_${i}_listdirs_valid_users.sh

	echo "$i curl used to UP and DWNLD files - listdirs valid users only"
	ssh $CLIENT $suite/client/bin/04_${i}_listdirs_valid_users.sh $SERVER

	echo "Test vsftpd service with $i listdirs valid users only chroot"
	ssh $SERVER $suite/server/bin/07_${i}_listdirs_valid_users_chroot.sh

	echo "$i curl used to UP and DWNLD files - listdirs valid users only chroot"
	ssh $CLIENT $suite/client/bin/05_${i}_listdirs_valid_users_chroot.sh $SERVER

	echo "Test vsftpd service with $i listdirs invalid chrootperms\n###\n"
	ssh $SERVER $suite/server/bin/08_${i}_listdirs_invalid_chrootperms.sh

	echo "$i curl used to UP and DWNLD files - listdirs invalid chrootperms"
	ssh $CLIENT $suite/client/bin/06_${i}_listdirs_invalid_chrootperms.sh $SERVER
done

# }}}
