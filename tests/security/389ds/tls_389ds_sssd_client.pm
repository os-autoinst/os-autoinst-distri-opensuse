# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Implement & Integrate 389ds + sssd test case into openQA,
#          This test module covers the sssd client tests
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#88513, poo#92410, tc#1768672

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use Utils::Systemd qw(systemctl disable_and_stop_service);

sub run {
    select_console("root-console");

    my $remote_ip   = '10.0.2.101';
    my $remote_name = '389ds';
    my $inst_ca_dir = '/etc/dirsrv/slapd-localhost';
    my $tls_dir     = '/etc/openldap/certs';
    my $ldap_user   = $testapi::username;
    my $uid         = '1003';

    # Install 389-ds and sssd on client
    zypper_call("in 389-ds sssd sssd-ldap openssl");

    # Disable and stop the nscd daemon because it conflicts with sssd
    disable_and_stop_service("nscd", ignore_failure => 1);

    # Copy the /etc/hosts, sample sssd.conf and CA files from server
    # Configure tls CA key on client
    mutex_wait("389DS_READY");
    assert_script_run("mkdir -p $tls_dir");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@$remote_ip:/etc/hosts /etc/hosts");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@$remote_ip:/tmp/sssd.conf /tmp");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@$remote_ip:$inst_ca_dir/ca.crt $tls_dir");
    assert_script_run("/usr/bin/openssl rehash $tls_dir");

    # On newer environments, nsswitch.conf is located in /usr/etc
    # Copy it to /etc directory
    script_run("f=/etc/nsswitch.conf; [ ! -f \$f ] && cp /usr\$f \$f");
    assert_script_run("sed -i -e '/^passwd.*/ s/\$/ sss/' -e '/^group.*/ s/\$/ sss/' -e '/^shadow.*/ s/\$/ sss/' /etc/nsswitch.conf");

    # Configure pam to enable sssd
    assert_script_run("pam-config -a --sss");
    assert_script_run("pam-config -q --sss");

    # Now, we can start the sssd service
    assert_script_run("cat /tmp/sssd.conf > /etc/sssd/sssd.conf");
    systemctl("enable sssd");
    systemctl("start sssd");

    # Verify the sssd client can communicate with server in secure mode
    # Make sure ldap user can login from client as well
    assert_script_run("LDAPTLS_REQCERT=never ldapwhoami -H ldaps://$remote_name.example.com:636 -x");
    assert_script_run("id $ldap_user | grep $uid");
}

sub post_fail_hook {
    upload_logs("/var/log/messages");
    upload_logs("/etc/sssd/sssd.conf");
}

1;
