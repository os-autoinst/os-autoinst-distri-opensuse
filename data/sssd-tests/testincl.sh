# Common features for SSSD testing scenarios
# Please only use these functions in test case sub-directory

source /usr/local/bin/version_utils.sh

SLAPD="/usr/sbin/slapd"
[ ! -e "$SLAPD" ] && SLAPD=/usr/lib/openldap/slapd

SSS_RELATED_UNITS='nscd.service nscd.socket krb5kdc.service kadmind.service sssd.service slapd.service'

# Comprehensive list of system-wide configuration files touched by test cases
declare -a bakfiles=(/etc/hosts /etc/nsswitch.conf /etc/krb5.conf /var/lib/kerberos/krb5kdc/kdc.conf)

sssd_test_common_setup() {
	# Let PAM know SSS
	pam-config -d --krb5 --ldap
	pam-config -a --sss

	# Disable potentially conflicting system services
	systemctl stop $SSS_RELATED_UNITS &> /dev/null || true
	systemctl disable $SSS_RELATED_UNITS &> /dev/null || true
	killall -TERM sssd slapd krb5kdc kadmind &> /dev/null || true

	# Create backup for the system-wide config files
	for file in "${bakfiles[@]}"; do
		if [ -e "$file" ]; then
			cp "$file" "$file.bak"
		fi
	done

	# Clear existing SSS databases
	rm -rf /var/lib/sss/db/* || true
	rm -rf /usr/local/var/lib/sss/db/* || true
	rm -rf /var/log/sssd/* || true

	# Clean up after previously failed tests
	rm -rf /home/testuser* /var/spool/mail/testuser* /tmp/ldap-sssdtest* /tmp/ldap-krb-keyfile || true
	echo -n > /etc/krb5.conf
	echo -n > /var/lib/kerberos/krb5kdc/kdc.conf || true

	# Enable Unix and SSS name switches
	sed -i 's/^passwd:.*/passwd: compat sss/' /etc/nsswitch.conf
	sed -i 's/^group:.*/group: compat sss/' /etc/nsswitch.conf

	# Fix ownership and permission of sssd configuration file
	chmod 600 sssd.conf && chown root:root sssd.conf
}

sssd_test_common_cleanup() {
	# Kill all related processes
	killall -TERM sssd slapd krb5kdc kadmind &> /dev/null || true
	systemctl stop $SSS_RELATED_UNITS &> /dev/null || true

	# Clean up for the files created during test case
	rm -rf /home/testuser* /var/spool/mail/testuser* /tmp/ldap-sssdtest* /tmp/ldap-krb-keyfile || true

	# Clear SSS databases
	rm -rf /var/lib/sss/db/* || true
	rm -rf /usr/local/var/lib/sss/db/* || true

	# Restore PAM settings
	pam-config -d --sss --krb5 --ldap

	# Restore system-wide configuration files
	for file in "${bakfiles[@]}"; do
		if [ -e "$file.bak" ]; then
			cp "$file.bak" "$file"
		fi
	done
}

test_suite_start() {
	../junit.sh testsuite -t "$1"
}

test_suite_end() {
	../junit.sh endsuite -t "$1"
}

test_case() {
	../junit.sh testcase -i "$SPECNAME" -t "$1"
}

test_ok() {
	../junit.sh success
}

test_fatal() {
	../junit.sh failure -T "$1"
	exit 1
}

test_abort() {
	../junit.sh error -T "$1"
	exit 1
}


#########################################################################
###
### Returns 0 if python3 should be used
###
### Example:
### usePython3
### echo $?

usePython3(){
   if ( isSles15 ) || ( isLeap15 ) || ( isTumbleweed ); then
      return 0
   fi
   return 1
}
