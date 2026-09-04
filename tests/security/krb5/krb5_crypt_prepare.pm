# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Prepare environment for cryptographic function testing of krb5
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#81236

use Mojo::Base 'consoletest';
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
        # In a chain topology (KDC -> Server -> Client), barriers are only visible
        # within each direct parallel sub-group: {KDC, Server} and {Server, Client}.
        # The Client cannot see barriers created by KDC (grandparent).
        # Therefore, KDC creates count=2 barriers for the {KDC, Server} sub-group,
        # and the Server creates separate barriers for the {Server, Client} sub-group.
        barrier_create('KRB5_NETWORK_READY', 2);
        barrier_create('KRB5_KDC_READY', 2);
        barrier_create('KRB5_NFS_TEST_DONE', 2);
        barrier_create('KRB5_SSH_TEST_DONE', 2);
        mutex_create('KRB5_KDC_BARRIERS_READY');
        krb5_network_config($ip_kdc, $dom_kdc);
        barrier_wait('KRB5_NETWORK_READY');
    }
    elsif (get_var('SECURITY_TEST') =~ /crypt_krb5server/) {
        mutex_wait('KRB5_KDC_BARRIERS_READY');
        # Create barriers for the {Server, Client} sub-group.
        # Barriers suffixed with _SC mirror the KDC's barriers for the Client.
        # Server-only barriers (count=2) are also created here since the Client
        # can only see barriers from its direct parent (Server).
        barrier_create('KRB5_NETWORK_READY_SC', 2);
        barrier_create('KRB5_KDC_READY_SC', 2);
        barrier_create('KRB5_SERVER_READY', 2);
        barrier_create('KRB5_NFS_SERVER_READY', 2);
        barrier_create('KRB5_SSH_SERVER_READY', 2);
        barrier_create('KRB5_NFS_TEST_DONE_SC', 2);
        barrier_create('KRB5_SSH_TEST_DONE_SC', 2);
        mutex_create('KRB5_SERVER_BARRIERS_READY');
        krb5_network_config($ip_server, $dom_server);
        barrier_wait('KRB5_NETWORK_READY');
        barrier_wait('KRB5_NETWORK_READY_SC');
        assert_script_run("ping -c1 $ip_kdc");
    }
    elsif (get_var('SECURITY_TEST') =~ /crypt_krb5client/) {
        # Wait for the Server to signal that barriers are ready to use.
        # Since mutex_wait() checks the direct parent by default (KDC -> Server -> Client),
        # the Client must wait on the Server's relay mutex, not the KDC's original mutex.
        mutex_wait('KRB5_SERVER_BARRIERS_READY');
        krb5_network_config($ip_client, $dom_client);
        barrier_wait('KRB5_NETWORK_READY_SC');
        assert_script_run("ping -c1 $ip_kdc");
        assert_script_run("ping -c1 $ip_server");
    }
    else {    # Avoid misconfiguration in lib/main_common.pm
        die "Unrecognized value of SECURITY_TEST";
    }

    # Prepare hosts file for domains
    my $hosts_content = <<END;
$ip_kdc $dom_kdc
$ip_server $dom_server
$ip_client $dom_client
END
    write_sut_file("/etc/hosts", $hosts_content);

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
    my $krb5_conf_content = <<END;
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
END
    write_sut_file($krb5_conf, $krb5_conf_content);
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
