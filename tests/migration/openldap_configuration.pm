# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: The module attempts to save openldap configuration files in
#          the system.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use Utils::Systemd qw(systemctl disable_and_stop_service);
use version_utils qw(is_tumbleweed is_sle);
use Utils::Logging 'tar_and_upload_log';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Install openldap since we need use slaptest tools
    zypper_call("in sssd sssd-tools sssd-ldap openldap2 openldap2-client");

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
    my $slapd_command = (is_sle('<=12-sp5')) ? "/usr/lib/openldap/slapd" : "slapd";
    assert_script_run "$slapd_command -h 'ldap:///' -f slapd.conf";

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
    assert_script_run "mkdir slapd.d";
    assert_script_run "slaptest -f slapd.conf -F ./slapd.d";

}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    tar_and_upload_log('/var/log/sssd', '/tmp/sssd.tar.bz2');
    $self->SUPER::post_fail_hook;
}

1;
