# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Prepare environment for cryptographic function testing of krb5
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#81236

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;
use mm_tests;
use mm_network;
use Exporter;
use version_utils "is_sle";
use krb5crypt;    # Import public variables

sub krb5_network_config {
    my ($ip, $dom) = @_;

    # The hostname should be fixed to "krb5kdc", "krb5server" and "krb5client"
    my $hostname = 'krb5' . (split('\.', $dom))[0];
    set_hostname($hostname);
    assert_script_run("hostname");

    # Append to /etc/hosts
    assert_script_run("sed -i \"s/\\($ip.*\$\\)/\\1 $hostname/g\" /etc/hosts");
    assert_script_run("cat /etc/hosts");

    configure_static_network("$ip/24");
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    my $children = get_children();

    # Prepare hosts file for domains
    assert_script_run(
        "echo \"\$(cat <<EOF
$ip_kdc $dom_kdc
$ip_server $dom_server
$ip_client $dom_client
EOF
        )\" >> /etc/hosts"
    );

    # Network configuration
    # We do not only simply setup the network environment, but also ensure the
    # Connections with lock api.
    if (get_var('SECURITY_TEST') =~ /crypt_krb5kdc/) {
        krb5_network_config($ip_kdc, $dom_kdc);

        mutex_create "KRB5_KDC_NETWORK_READY";
        # Make sure three machines finishing the network setting at almost
        # same time for better modulization.
        mutex_wait("KRB5_SERVER_NETWORK_READY", (keys %$children)[0]);
    }
    elsif (get_var('SECURITY_TEST') =~ /crypt_krb5server/) {
        krb5_network_config($ip_server, $dom_server);

        mutex_wait "KRB5_KDC_NETWORK_READY";
        assert_script_run("ping -c1 $ip_kdc");

        mutex_create "KRB5_SERVER_NETWORK_READY";
        mutex_wait("KRB5_CLIENT_NETWORK_READY", (keys %$children)[0]);
    }
    elsif (get_var('SECURITY_TEST') =~ /crypt_krb5client/) {
        krb5_network_config($ip_client, $dom_client);

        mutex_wait "KRB5_SERVER_NETWORK_READY";
        assert_script_run("ping -c1 $ip_kdc");
        assert_script_run("ping -c1 $ip_server");

        mutex_create "KRB5_CLIENT_NETWORK_READY";
    }
    else {    # Avoid misconfigration in lib/main_comman.pm
        die "Unrecognized value of SECURITY_TEST";
    }

    (is_sle('<15')) ? systemctl('stop SuSEfirewall2') : systemctl('stop firewalld');

    # Prepare krb5 application and config files
    zypper_call('ref');
    zypper_call('lr -u');
    zypper_call('in krb5 krb5-server krb5-client');
    assert_script_run("echo 'export KRB5CCNAME=/root/kcache' >> /etc/profile.d/krb5.sh");    # Make ticket permanent
    assert_script_run("source /etc/profile.d/krb5.sh");

    my $krb5_conf = '/etc/krb5.conf';
    assert_script_run "cat $krb5_conf";
    assert_script_run(
        "echo \"\$(cat <<EOF
[libdefaults]
    dns_canonicalize_hostname = false
    rdns = false
    default_realm = EXAMPLE.COM
    allow_week_crypto = true
    ignore_acceptor_hostname = true

[realms]
        EXAMPLE.COM = {
                kdc = kdc.example.com
                admin_server = kdc.example.com
        }

[domain_realm]
.example.com = EXAMPLE.COM

[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON
EOF
        )\" > $krb5_conf"
    );
    assert_script_run "cat $krb5_conf";

    if (get_var('SECURITY_TEST') =~ /crypt_krb5kdc/) {

        # KDC configuration
        my $kdc_conf = "/var/lib/kerberos/krb5kdc/kdc.conf";
        assert_script_run "cat $kdc_conf";
        assert_script_run "sed -i 's/^#/ /g' $kdc_conf";
        assert_script_run "cat $kdc_conf";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
