# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for 389ds sssd client service tests
#
# Maintainer: QE Security <none@suse.de>

package services::389ds_sssd;
use base 'consoletest';
use testapi;
use utils;
use warnings;
use strict;
use network_utils 'iface';
use Utils::Architectures 'is_s390x';
use utils qw(set_hostname);
use Utils::Systemd qw(disable_and_stop_service systemctl);

my $remote_name = '389ds';
my $inst_ca_dir = '/etc/dirsrv/slapd-localhost';
my $tls_dir = '/etc/openldap/certs';
my $ldap_user = get_var('SSS_USERNAME');
my $uid = '1003';

sub install_service {
    zypper_call("in 389-ds sssd sssd-ldap openssl");
    # Disable and stop the nscd daemon because it conflicts with sssd
    disable_and_stop_service("nscd", ignore_failure => 1);
}

# The function below covers all required steps for 389ds sssd client's configuration
sub config_service {
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');
    if (is_s390x) {
        assert_script_run("ip addr add $client_ip/24 dev " . iface);
        assert_script_run("echo \"$client_ip client minion\" >> /etc/hosts");
        disable_and_stop_service('firewalld', ignore_failure => 1);
        disable_and_stop_service('apparmor', ignore_failure => 1);
    }

    # Copy the /etc/hosts, sample sssd.conf and CA files from server
    # Configure tls CA key on client
    assert_script_run("mkdir -p $tls_dir");
    my $ssh_port = is_s390x ? '-P 2222' : '';
    exec_and_insert_password("scp $ssh_port -o StrictHostKeyChecking=no root\@$server_ip:/etc/hosts /etc/hosts");
    exec_and_insert_password("scp $ssh_port -o StrictHostKeyChecking=no root\@$server_ip:/tmp/sssd.conf /tmp");
    exec_and_insert_password("scp $ssh_port -o StrictHostKeyChecking=no root\@$server_ip:$inst_ca_dir/ca.crt $tls_dir");
    assert_script_run("/usr/bin/openssl rehash $tls_dir");
    assert_script_run("chmod o+r $tls_dir/ca.crt");    # From version 2.10 onwards sssd runs as user "sssd"

    # On newer environments, nsswitch.conf is located in /usr/etc
    # Copy it to /etc directory
    script_run("f=/etc/nsswitch.conf; [ ! -f \$f ] && cp /usr\$f \$f");
    assert_script_run("sed -i -e '/^passwd.*/ s/\$/ sss/' -e '/^group.*/ s/\$/ sss/' -e '/^shadow.*/ s/\$/ sss/' /etc/nsswitch.conf");

    # Configure pam to enable sssd
    assert_script_run("pam-config -a --sss");
    assert_script_run("pam-config -q --sss");

    # Write the sssd configuration file
    assert_script_run('install --mode 0600 -D /tmp/sssd.conf /etc/sssd/sssd.conf');
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
