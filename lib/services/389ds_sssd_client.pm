# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for 389ds sssd client service tests
#
# Maintainer: QE Security <none@suse.de>

package services::389ds_sssd;
use base 'opensusebasetest';
use testapi;
use utils;
use warnings;
use strict;
use Utils::Systemd 'disable_and_stop_service';

our @EXPORT = qw($remote_ip $remote_name $inst_ca_dir $tls_dir $ldap_user $uid);
our $remote_ip = '10.0.2.101';
our $remote_name = '389ds';
our $inst_ca_dir = '/etc/dirsrv/slapd-localhost';
our $tls_dir = '/etc/openldap/certs';
our $ldap_user = get_var('SSS_USERNAME');
our $uid = '1003';

sub install_service {
    zypper_call("in 389-ds sssd sssd-ldap openssl");
    # Disable and stop the nscd daemon because it conflicts with sssd
    disable_and_stop_service("nscd", ignore_failure => 1);
}

# The function below covers all required steps for 389ds sssd client's configuration
sub config_service {
    # Copy the /etc/hosts, sample sssd.conf and CA files from server
    # Configure tls CA key on client
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

    # Write the sssd configuration file
    assert_script_run("cat /tmp/sssd.conf > /etc/sssd/sssd.conf");
}

sub start_service {
    systemctl("start sssd");
}

sub enable_service {
    systemctl("enable sssd");
}

sub check_service {
    systemctl("is-active sssd");
    # Verify the sssd client can communicate with server in secure mode
    # Make sure ldap user can login from client as well
    assert_script_run("LDAPTLS_REQCERT=never ldapwhoami -H ldaps://$remote_name.example.com:636 -x");
    assert_script_run("id $ldap_user | grep $uid");
}

1;
