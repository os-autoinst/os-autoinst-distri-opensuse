#!/bin/bash

set -e

. ../testincl.sh
trap sssd_test_common_cleanup EXIT SIGINT SIGTERM
sssd_test_common_setup

export SPECNAME=sssd.ldap_inherited_groups
test_suite_start 'Use SSSD with LDAP backend and inherited/nested group membership'

# Prepare LDAP certificates and database
mkdir -p /tmp/ldap-sssdtest &&
cp ldap.crt /tmp/ldap-sssdtest.cacrt &&
cp ldap.crt /tmp/ldap-sssdtest.crt &&
cp ldap.key /tmp/ldap-sssdtest.key &&
/usr/sbin/slapd -h 'ldap:///' -f slapd.conf &&
sleep 2 &&
ldapadd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -f db.ldif &> /dev/null || test_abort 'Failed to prepare LDAP server'

test_case 'Start SSSD'
sssd -f -c sssd.conf || test_fatal 'Failed to start SSSD'
test_ok

test_case 'Look up users in LDAP via SSSD'
lookup_success=0
for i in {1..60}; do
	if getent passwd user1@ldapdom &> /dev/null; then
		lookup_success=1
		break
	else
		echo Still waiting for user record to appear in database..
		sleep 1
	fi
done
if [ "$lookup_success" != "1" ]; then
	echo User record did not show up && exit 1
fi
[ "$lookup_success" == "1" ] || test_fatal 'User record did not show up in database'
getent passwd root &> /dev/null &&
getent passwd user2@ldapdom &> /dev/null &&
getent passwd user3@ldapdom &> /dev/null &&
! getent passwd doesnotexist@ldapdom &> /dev/null || test_fatal  'Failed to look up multiple users'
test_ok

# ID the users first, otherwise SSSD cannot figure out group's additional users, by design? 
id user1 &> /dev/null
id user2 &> /dev/null
id user3 &> /dev/null

#test_case 'Look up groups in LDAP via SSSD'
#for i in {0..5}; do
#	group1=`getent group All1`
#	[ "$group1" = "All1:*:8000:user2" ] || test_fatal 'group1 user list is incomplete'
#	group2=`getent group All2`
#	[ "$group2" = "All2:*:8001:user3" ] || test_fatal 'group2 user list is incomplete'
#done
#test_ok

test_case 'Switch user'
su user1 -c true && 
su user2 -c true && 
su user3 -c true || test_fatal 'Failed to switch to users'
test_ok

test_case 'User group membership'
for i in {0..5}; do
	user1_groups=`su user1 -c 'id -G'`
	user2_groups=`su user2 -c 'id -G'`
	user3_groups=`su user3 -c 'id -G'`
	[ "$user1_groups" = "8000" ] || test_fatal 'user1 group membership is incomplete'
	[ "$user2_groups" = "8000" ] || test_fatal 'user2 group membership is incomplete'
	[ "$user3_groups" = "8001" ] || test_fatal 'user3 group membership is incomplete'
done
test_ok

test_case 'Check password status'
passwd -S user1@ldapdom &> /dev/null &&
passwd -S user2@ldapdom &> /dev/null &&
passwd -S user3@ldapdom &> /dev/null || test_fatal 'Failed to check password status'
! passwd -S doesnotexist@ldapdom &> /dev/null || test_fatal 'Non-existing user showed up in passwd'
test_ok

ldappasswd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -sgoodpass 'cn=user1,ou=UnixUser,dc=ldapdom,dc=net'
test_case 'Login via PAM'
../pamtest.py login user1 goodpass || test_fatal 'Failed to login as testuser1'
! ../pamtest.py login user1 badpass &> /dev/null || test_fatal 'Failed to deny login of incorrect password'
! ../pamtest.py login doesnotexist badpass &> /dev/null || test_fatal 'Failed to deny login of false username'
test_ok

test_suite_end

