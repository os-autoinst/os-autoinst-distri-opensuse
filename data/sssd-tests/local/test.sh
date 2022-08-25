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

export SPECNAME=sssd.localdb
test_suite_start 'Use SSSD with a local user database'

test_case 'Start SSSD'
sssd --logger=files -c sssd.conf || test_fatal 'Failed to start SSSD'
test_ok

test_case 'Add users'
sss_useradd testuser1 && sss_useradd testuser2 || test_fatal 'Failed to add new users'
test_ok

test_case 'Look up users in name database'
lookup_success=0
for i in {1..60}; do
	if getent passwd testuser1@LOCAL &> /dev/null; then
		lookup_success=1
		break
	else
		echo Still waiting for user record to appear in database..
		sleep 1
	fi
done
[ "$lookup_success" == "1" ] || test_fatal 'User record did not show up in database'
getent passwd root &> /dev/null &&
getent passwd testuser2@LOCAL &> /dev/null &&
! getent passwd testuser3@LOCAL &> /dev/null || test_fatal 'Failed to look up multiple users'
test_ok

test_case 'Delete user'
sss_userdel testuser2 || test_fatal 'Failed to delete user'
! getent passwd testuser2@LOCAL || test_fatal 'Deleted user is still showing up in database'
test_ok

test_case 'Switch user'
su testuser1 -c true || test_fatal 'Failed to switch to testuser1'
! su testuser2 -c true &> /dev/null || test_fatal 'Deleted user is still usable'
test_ok

test_case 'Check password status'
passwd -S testuser1 &> /dev/null || test_fatal 'Failed to check password status'
! passwd -S testuser2 &> /dev/null || test_fatal 'Deleted user still shows up in passwd'
test_ok

echo 'testuser1@LOCAL:goodpass' | chpasswd
test_case 'Authentication via PAM'
$PYTHON ../pamtest.py passwd testuser1 goodpass || test_fatal 'Failed to authentication testuser1'
! $PYTHON ../pamtest.py passwd testuser1 badpass &> /dev/null || test_fatal 'Failed to deny false password for testuser1'
! $PYTHON ../pamtest.py passwd testuser2 badpass &> /dev/null || test_fatal 'Failed to deny false username'
test_ok

test_case 'Login via PAM'
$PYTHON ../pamtest.py login testuser1 goodpass || test_fatal 'Failed to login as testuser1'
! $PYTHON ../pamtest.py login testuser1 badpass &> /dev/null || test_fatal 'Failed to deny login of incorrect password'
! $PYTHON ../pamtest.py login testuser2 badpass &> /dev/null || test_fatal 'Failed to deny login of false username'
test_ok

test_suite_end
