# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: The openldap_to_ds tool will attempt to automatically migrate
# custom schema, backens, some overlays from openldap to 389ds.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use Utils::Systemd qw(systemctl);
use version_utils;
use Utils::Logging 'tar_and_upload_log';

sub run {
    my ($self) = @_;
    my $password = $testapi::password;
    select_serial_terminal;

    # Install 389-ds
    zypper_call("in 389-ds");
    zypper_call('info 389-ds');

    # Prepare data file for migration
    assert_script_run("cd test");
    assert_script_run "sed -i 's/^root_password.*/root_password = $password/' ./instance.inf";
    assert_script_run("dscreate from-file ./instance.inf", timeout => 180);
    assert_script_run("echo '127.0.0.1    susetest' >> /etc/hosts");
    assert_script_run "dsctl localhost status";

    # Check migration tools
    tar_and_upload_log('./slapd.d', 'slapd.d.tar.bz2');
    upload_logs("./db.ldif", timeout => 100);
    upload_logs("./slapd.conf", timeout => 100);
    assert_script_run "openldap_to_ds -v --confirm localhost ./slapd.d ./db.ldif > ldap2dslog";
    upload_logs("./ldap2dslog", timeout => 100);
    assert_script_run "ldapmodify -H ldap://localhost -x -D 'cn=Directory Manager' -w $password -f aci.ldif";

    # Check refint and unique plugins status
    my $out = script_output "dsconf localhost plugin attr-uniq list";
    my @cn = split('\n', $out);
    validate_script_output("dsconf localhost plugin attr-uniq show $cn[-1]", sub { m/nsslapd-pluginEnabled: on/ });
    validate_script_output("dsconf localhost plugin referential-integrity show", sub { m/nsslapd-pluginEnabled: on/ });

    # Manual fix memberof plugin
    assert_script_run "dsconf localhost plugin memberof show";
    assert_script_run "systemctl restart dirsrv\@localhost";
    assert_script_run "dsconf localhost plugin memberof fixup dc=ldapdom,dc=net -f '(objectClass=*)'";
    validate_script_output("dsconf localhost plugin memberof show", sub { m/nsslapd-pluginEnabled: on/ });

    # Restart sssd make sure re-detect backend
    systemctl("restart sssd");
    systemctl("status sssd");

    # check memeberof plugin
    validate_script_output("ldapsearch -H ldap://localhost -b 'dc=ldapdom,dc=net' -s sub -x -D 'cn=Directory Manager' -w $password memberof", sub { m/memberof:.*group1/ });
    validate_script_output('getent passwd testuser1\@ldapdom', sub { m/testuser1.*testuser1/ });

}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    tar_and_upload_log('/var/log/dirsrv', '/tmp/ds389.tar.bz2');
    $self->SUPER::post_fail_hook;
}

1;
