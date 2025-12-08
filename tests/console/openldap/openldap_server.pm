# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Reenable openldap testing for 15SP5+
#
# Maintainer: QE Core <qe-core@suse.de>
# Tags: poo#165258

use base 'consoletest';
use testapi;
use utils;
use lockapi;
use mmapi 'wait_for_children';
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    select_serial_terminal;

    my $ldap_server_ver = "openldap2_5";

    if (is_sle('>=16.0')) {
        $ldap_server_ver = "openldap2_6";
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
    }

    zypper_call("in $ldap_server_ver openldap2-client");
    assert_script_run qq(sed -i 's/server/ldapserver/g' /etc/hosts);
    assert_script_run qq(sed -i 's/client/ldapclient/g' /etc/hosts);

    # Setup openldap database and import testing data
    assert_script_run('cd /etc/openldap');
    assert_script_run('curl -s --remote-name-all ' . data_url('sssd/openldap/{user.ldif,slapd.conf,ldapserver.key,ldapserver.crt,ldapserver.csr}'));
    assert_script_run('curl -o /etc/openldap/schema/sudo.schema ' . data_url('sssd/openldap/sudo.schema'));
    # Modify sysconfig file and enable LDAPI
    assert_script_run qq(sed -i "/^OPENLDAP_LDAPI_INTERFACES/c\\OPENLDAP_LDAPI_INTERFACES='yes'" /etc/sysconfig/openldap);
    # Add entries to a SLAPD database
    assert_script_run('slapadd -b dc=sssdtest,dc=com -l /etc/openldap/user.ldif');
    assert_script_run('chown -R ldap:ldap /var/lib/ldap/');
    # Start OpenLDAP Server Daemon
    systemctl('start slapd.service');

    # Add lock for client
    mutex_create("Openldap_server_READY");

    # Finish job
    wait_for_children;
}

sub post_fail_hook {
    upload_logs('/var/log/messages');
    upload_logs('/etc/openldap/slapd.conf');
    upload_logs('/etc/openldap/user.ldif');
    upload_logs('/etc/sysconfig/openldap');
}

1;
