#!/bin/bash

set -e

. ../testincl.sh

if ( usePython3 ); then
	PYTHON=python3
else
	PYTHON=python2
fi

trap sssd_test_common_cleanup EXIT SIGINT SIGTERM
sssd_test_common_setup

export SPECNAME=sssd.ldap_nested_groups
test_suite_start 'Use SSSD with LDAP backend and nested/multiple group membership'

# Prepare LDAP certificates and database
mkdir -p /tmp/ldap-sssdtest &&
cp ldap.crt /tmp/ldap-sssdtest.cacrt &&
cp ldap.crt /tmp/ldap-sssdtest.crt &&
cp ldap.key /tmp/ldap-sssdtest.key &&
$SLAPD -h 'ldap:///' -f slapd.conf &&
sleep 2 &&
ldapadd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -f db.ldif &> /dev/null || test_abort 'Failed to prepare LDAP server'

test_case 'Start SSSD'
sssd --logger=files -c sssd.conf || test_fatal 'Failed to start SSSD'
test_ok

test_case 'Look up users in LDAP via SSSD'
lookup_success=0
for i in {1..60}; do
	if getent passwd testuser1@ldapdom &> /dev/null; then
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
getent passwd testuser2@ldapdom &> /dev/null &&
! getent passwd doesnotexist@ldapdom &> /dev/null || test_fatal  'Failed to look up multiple users'
test_ok

test_case 'Look up groups in LDAP via SSSD'
group1=`getent group group1`
[ "$group1" = "group1:*:8000:testuser1,testuser2" ] || test_fatal 'group1 user list is incomplete'
group2=`getent group group2`
[ "$group2" = "group2:*:8001:testuser1" ] || test_fatal 'group2 user list is incomplete'
group3=`getent group group3`
[ "$group3" = "group3:*:8002:testuser2" ] || test_fatal 'group3 user list is incomplete'
supergroup=`getent group supergroup`
[ "$supergroup" = "supergroup:*:8003:testuser1,testuser2" ] || test_fatal 'supergroup user list is incomplete'
test_ok

test_case 'Switch user'
su testuser1 -c true &&
su testuser2 -c true || test_fatal 'Failed to switch to users'
test_ok

test_case 'User group membership'
user1_groups=`su testuser1 -c 'id -G'`
user2_groups=`su testuser2 -c 'id -G'`
[ "$user1_groups" = "8000 8001 8003" ] || test_fatal 'testuser1 group membership is incomplete'
[ "$user2_groups" = "8000 8002 8003" ] || test_fatal 'testuser2 group membership is incomplete'
test_ok

test_case 'Check password status'
passwd -S testuser1@ldapdom &> /dev/null &&
passwd -S testuser2@ldapdom &> /dev/null || test_fatal 'Failed to check password status'
! passwd -S doesnotexist@ldapdom &> /dev/null || test_fatal 'Non-existing user showed up in passwd'
test_ok

ldappasswd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -sgoodpass 'uid=testuser1,ou=UnixUser,dc=ldapdom,dc=net'
test_case 'Login via PAM'
$PYTHON ../pamtest.py login testuser1 goodpass || test_fatal 'Failed to login as testuser1'
! $PYTHON ../pamtest.py login testuser2 badpass &> /dev/null || test_fatal 'Failed to deny login of incorrect password'
! $PYTHON ../pamtest.py login doesnotexist badpass &> /dev/null || test_fatal 'Failed to deny login of false username'
test_ok

test_suite_end
