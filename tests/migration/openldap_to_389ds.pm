# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: The openldap_to_ds tool will attempt to automatically migrate
# custom schema, backens, some overlays from openldap to 389ds.
#
# Maintainer: wegao <wegao@suse.com>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use lockapi;
use Utils::Systemd qw(systemctl disable_and_stop_service);
use registration qw(add_suseconnect_product);
use version_utils;
use Utils::Logging 'tar_and_upload_log';

sub run {
    my ($self) = @_;
    my $password = $testapi::password;
    select_serial_terminal;

    # Install 389-ds and sssd on client
    zypper_call("in 389-ds sssd sssd-tools");
    zypper_call('info 389-ds');
    # Install openldap since we need use slaptest tools
    if (is_sle) {
        my $openldap = get_required_var("OPENLDAP_PKG");
        assert_script_run('wget ' . $openldap, 200);
        my @ldap = split('/', $openldap);
        assert_script_run 'rpm -i ' . $ldap[-1];
    } else {
        zypper_call("in openldap2");
    }
    zypper_call("in sssd-ldap openldap2-client");

    # Disable and stop the nscd daemon because it conflicts with sssd
    disable_and_stop_service("nscd");

    # On newer environments, nsswitch.conf is located in /usr/etc
    # Copy it to /etc directory
    script_run 'f=/etc/nsswitch.conf; [ ! -f $f ] && cp /usr$f $f';
    # Configure nsswitch with sssd
    assert_script_run "sed -i 's/^passwd:.*/passwd: compat sss/' /etc/nsswitch.conf";
    assert_script_run "sed -i 's/^group:.*/group: compat sss/' /etc/nsswitch.conf";
    assert_script_run "cat /etc/nsswitch.conf";

    # Prepare test env
    assert_script_run "cd; curl -L -v " . autoinst_url . "/data/openldap_to_389ds > openldap_to_389ds.data && cpio -id < openldap_to_389ds.data && mv data test && ls test";
    assert_script_run("cd test");

    # We need start openldap to kick out date base file which stored in directory
    assert_script_run "mkdir /tmp/ldap-sssdtest";
    if (is_tumbleweed) {
        assert_script_run "sed -i -e '/cachesize/d' ./slapd.conf";
        assert_script_run "sed -i -e 's/hdb/mdb/g' ./slapd.conf";
        # for openqa debug
        permit_root_ssh;
    }
    assert_script_run "cat ./slapd.conf";
    assert_script_run "slapd -h 'ldap:///' -f slapd.conf";

    assert_script_run "ldapadd -x -D 'cn=root,dc=ldapdom,dc=net' -wpass -f db.ldif";
    assert_script_run "killall slapd";
    assert_script_run "ps -aux | grep slapd";

    # setup sssd
    assert_script_run "cp ./sssd.conf /etc/sssd/sssd.conf";
    systemctl("stop sssd");
    assert_script_run "rm -rf /var/lib/sss/db/*";
    systemctl("restart sssd");
    systemctl("status sssd");

    # Prepare data file for migration
    assert_script_run "sed -i 's/^root_password.*/root_password = $password/' ./instance.inf";
    assert_script_run "mkdir slapd.d";
    assert_script_run("dscreate from-file ./instance.inf", timeout => 180);
    assert_script_run("echo '127.0.0.1    susetest' >> /etc/hosts");
    assert_script_run "dsctl localhost status";
    assert_script_run "slaptest -f slapd.conf -F ./slapd.d";

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
    tar_and_upload_log('/var/log/sssd', '/tmp/sssd.tar.bz2');
    $self->SUPER::post_fail_hook;
}

1;
