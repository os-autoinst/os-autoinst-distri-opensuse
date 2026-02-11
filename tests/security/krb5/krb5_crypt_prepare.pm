# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Prepare environment for cryptographic function testing of krb5
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#81236

use base "consoletest";
use testapi;
use utils;
use lockapi;
use mmapi;
use mm_tests;
use mm_network;
use Exporter;
use version_utils 'is_sle';
use Utils::Architectures 'is_s390x';
use krb5crypt;    # Import public variables
use network_utils 'iface';
use serial_terminal 'select_serial_terminal';

sub krb5_network_config {
    my ($ip, $dom) = @_;

    # The hostname should be fixed to "krb5kdc", "krb5server" and "krb5client"
    my $hostname = 'krb5' . (split('\.', $dom))[0];
    set_hostname($hostname);
    assert_script_run("hostname");

    # Append to /etc/hosts
    assert_script_run("sed -i \"s/\\($ip.*\$\\)/\\1 $hostname/g\" /etc/hosts");
    assert_script_run("cat /etc/hosts");
    if (is_s390x) {
        # we add the private IP address to the existing network interface
        my $netdev = iface();
        assert_script_run("ip addr add $ip/24 dev $netdev");
        configure_static_dns(get_host_resolv_conf());
    }
    else {
        configure_static_network("$ip/24");
    }
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Network configuration
    # We do not only simply setup the network environment, but also ensure the
    # Connections with lock api.
    if (get_var('SECURITY_TEST') =~ /crypt_krb5kdc/) {
        barrier_create('KRB5_NETWORK_READY', 3);
        barrier_create('KRB5_KDC_READY', 3);
        barrier_create('KRB5_SERVER_READY', 2);
        barrier_create('KRB5_NFS_SERVER_READY', 2);
        barrier_create('KRB5_SSH_SERVER_READY', 2);
        barrier_create('KRB5_NFS_TEST_DONE', 3);
        barrier_create('KRB5_SSH_TEST_DONE', 3);
        # Create a final mutex to signal all jobs that barriers are ready to use
        # It must be used with mutex_wait() before any barrier_wait() calls in the child jobs
        mutex_create('KRB5_PREPARE_BARRIERS_READY');
        krb5_network_config($ip_kdc, $dom_kdc);
        barrier_wait('KRB5_NETWORK_READY');
    }
    elsif (get_var('SECURITY_TEST') =~ /crypt_krb5server/) {
        mutex_wait('KRB5_PREPARE_BARRIERS_READY');
        krb5_network_config($ip_server, $dom_server);
        barrier_wait('KRB5_NETWORK_READY');
        assert_script_run("ping -c1 $ip_kdc");
    }
    elsif (get_var('SECURITY_TEST') =~ /crypt_krb5client/) {
        mutex_wait('KRB5_PREPARE_BARRIERS_READY');
        krb5_network_config($ip_client, $dom_client);
        barrier_wait('KRB5_NETWORK_READY');
        assert_script_run("ping -c1 $ip_kdc");
        assert_script_run("ping -c1 $ip_server");
    }
    else {    # Avoid misconfiguration in lib/main_common.pm
        die "Unrecognized value of SECURITY_TEST";
    }

    # Prepare hosts file for domains
    assert_script_run(
        "echo \"\$(cat <<EOF
$ip_kdc $dom_kdc
$ip_server $dom_server
$ip_client $dom_client
EOF
        )\" >> /etc/hosts"
    );

    if (is_sle '<15') {
        systemctl('stop SuSEfirewall2');
    } else {
        systemctl('stop firewalld');
    }

    # Prepare krb5 application and config files
    zypper_call('ref');
    zypper_call('lr -u');
    zypper_call('in krb5 krb5-server krb5-client nfs-client');
    assert_script_run("echo 'export KRB5CCNAME=/root/kcache' >> /etc/profile.d/krb5.sh");    # Make ticket permanent


    assert_script_run("source /etc/profile.d/krb5.sh");

    my $algo = is_sle('<15-SP6') ? "aes256-cts-hmac-sha1-96" : "aes256-cts-hmac-sha384-192";
    my $krb5_conf = is_sle('<16.1') ? '/etc/krb5.conf' : '/usr/etc/krb5.conf';
    assert_script_run "cat $krb5_conf";
    assert_script_run(
        "echo \"\$(cat <<EOF
[libdefaults]
    fipslevel = 3
    dns_canonicalize_hostname = false
    rdns = false
    default_realm = EXAMPLE.COM
    allow_weak_crypto = false
    default_tgs_enctypes = $algo
    default_tkt_enctypes = $algo
    permitted_enctypes = $algo
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
        # The following two lines are needed for FIPS
        assert_script_run "awk -i inplace '/max_renewable_life/ {match(\$0, /^ +/); spaces = substr(\$0, RSTART, RLENGTH); print \$0 \"\\n\" spaces \"master_key_type = $algo\"; next} 1' $kdc_conf";
        assert_script_run "awk -i inplace '/master_key_type/ {match(\$0, /^ +/); spaces = substr(\$0, RSTART, RLENGTH); print \$0 \"\\n\" spaces \"supported_enctypes = $algo\"; next} 1' $kdc_conf";
        assert_script_run "cat $kdc_conf";
    }

}

sub test_flags {
    return {fatal => 1};
}

1;
