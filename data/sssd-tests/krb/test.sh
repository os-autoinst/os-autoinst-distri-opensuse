#!/bin/bash

set -e

. ../testincl.sh

if ( usePython3 ); then
	PYTHON=python3
else
	PYTHON=python2
fi

# kerberos.schema changing path /usr/share/kerberos/ldap/kerberos.schema
# https://bugzilla.suse.com/show_bug.cgi?id=1135543
if [ -f /usr/share/doc/packages/krb5/kerberos.schema ]; then
    CONF=slapd_old.conf
else
    CONF=slapd.conf
fi

trap sssd_test_common_cleanup EXIT SIGINT SIGTERM
sssd_test_common_setup

export PATH=/usr/lib/mit/bin:/usr/lib/mit/sbin:$PATH

export SPECNAME=sssd.ldapkrb
test_suite_start 'Use SSSD with Kerberos and LDAP backend'

# Prepare LDAP directory and copy LDAP certificates
echo '127.0.0.1 krb.ldapdom.net' >> /etc/hosts &&
mkdir -p /tmp/ldap-sssdtest &&
cp ldap.crt /tmp/ldap-sssdtest.cacrt &&
cp ldap.crt /tmp/ldap-sssdtest.crt &&
cp ldap.key /tmp/ldap-sssdtest.key &&
$SLAPD -h 'ldap:///' -f $CONF &&
sleep 2 &&
ldapadd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -f db.ldif &> /dev/null &&
ldappasswd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -spass 'cn=krbkdc,dc=ldapdom,dc=net' &&
ldappasswd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -spass 'cn=krbadm,dc=ldapdom,dc=net' || test_abort 'Failed to prepare LDAP server'

# Prepare configuration and DB for kerberos
mkdir -p /run/user/$UID &&
cp krb5.conf /etc/krb5.conf &&
cp ldap-krb-keyfile /tmp/ &&
cp kdc.conf /var/lib/kerberos/krb5kdc/kdc.conf || test_abort 'Failed to prepare Kerberos config files'

# Create kerberos keyfile, password is "pass"
#kdb5_ldap_util -D 'cn=root,dc=ldapdom,dc=net' -w pass stashsrvpw -f /tmp/ldap-krb-keyfile cn=krbkdc,dc=ldapdom,dc=net
#kdb5_ldap_util -D 'cn=root,dc=ldapdom,dc=net' -w pass stashsrvpw -f /tmp/ldap-krb-keyfile cn=krbadm,dc=ldapdom,dc=net
kdb5_ldap_util -H 'ldap://127.0.0.1' -D 'cn=root,dc=ldapdom,dc=net' -w pass create -r LDAPDOM.NET -subtrees 'ou=UnixUser,dc=ldapdom,dc=net' -s -P pass &> /dev/null || test_abort 'Failed to create Kerberos DB'

# Create users in krb and complete them with more ldap attributes
systemctl unmask krb5kdc kadmind &&
systemctl start krb5kdc kadmind &&
kadmin.local -r LDAPDOM.NET -q 'addprinc -x dn="uid=testuser1,ou=UnixUser,dc=ldapdom,dc=net" -pw goodpass testuser1' &> /dev/null &&
kadmin.local -r LDAPDOM.NET -q 'addprinc -x dn="uid=testuser2,ou=UnixUser,dc=ldapdom,dc=net" -pw goodpass testuser2' &> /dev/null || test_abort 'Failed to create Kerberos principles'
# SSSD's PAM responder now has trouble reading user password in version 1.14
# Workaround is discussed in https://lists.fedorahosted.org/archives/list/sssd-users@lists.fedorahosted.org/thread/D3C2DDA7EDIEPZLSWXE53TFY4GGAICRN/
kadmin.local -r LDAPDOM.NET -q 'modprinc +requires_preauth testuser1' &> /dev/null &&
kadmin.local -r LDAPDOM.NET -q 'modprinc +requires_preauth testuser2' &> /dev/null &&

test_case 'Start SSSD'
sssd --logger=files -c sssd.conf || test_fatal 'Failed to start SSSD'
test_ok

credentials_test() {
	mode=$1

	test_case "($mode) Look up users in LDAP and Kerberos via SSSD"
	getent passwd root &> /dev/null &&
	getent passwd testuser1@ldapdom &> /dev/null  &&
	getent passwd testuser2@ldapdom &> /dev/null &&
	! getent passwd doesnotexist@ldapdom &> /dev/null || test_fatal "($mode) Failed to look up multiple users"
	test_ok

	test_case "($mode) Look up groups in LDAP via SSSD"
	group1=`getent group group1`
	[ "$group1" = "group1:*:8000:testuser1,testuser2" ] || test_fatal "($mode) group1 user list is incomplete"
	group2=`getent group group2`
	[ "$group2" = "group2:*:8001:testuser1" ] || test_fatal "($mode) group2 user list is incomplete"
	group3=`getent group group3`
	[ "$group3" = "group3:*:8002:testuser2" ] || test_fatal "($mode) group3 user list is incomplete"
	test_ok

	test_case "($mode) Switch user"
	su testuser1 -c true &&
	su testuser2 -c true || test_fatal "($mode) Failed to switch to users"
	test_ok

	test_case "($mode) User group membership"
	user1_groups=`su testuser1 -c 'id -G'`
	user2_groups=`su testuser2 -c 'id -G'`
	[ "$user1_groups" = "8000 8001" ] || test_fatal "($mode) testuser1 group membership is incomplete"
	[ "$user2_groups" = "8000 8002" ] || test_fatal "($mode) testuser2 group membership is incomplete"
	test_ok

	test_case "($mode) Check password status"
	passwd -S testuser1@ldapdom &> /dev/null &&
	passwd -S testuser2@ldapdom &> /dev/null || test_fatal "($mode) Failed to check password status"
	! passwd -S doesnotexist@ldapdom &> /dev/null || test_fatal "($mode) Non-existing user showed up in passwd"
	test_ok

	# Test user authentication and login, via PAM
	test_case "($mode) Login via PAM"
	$PYTHON ../pamtest.py login testuser1 goodpass &&
	$PYTHON ../pamtest.py login testuser2 goodpass || test_fatal "($mode) Failed to login"
	! $PYTHON ../pamtest.py login testuser2 badpass &> /dev/null || test_fatal "($mode) Failed to deny login of incorrect password"
	! $PYTHON ../pamtest.py login doesnotexist badpass &> /dev/null || test_fatal "($mode) Failed to deny login of false username"
	test_ok
}

# Online test
credentials_test 'Online'

# Offline test
systemctl stop kadmind krb5kdc && killall slapd || test_abort 'Failed to take backend services offline'
credentials_test 'Offline'

test_suite_end
