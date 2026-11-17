# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'ipsec' client case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101226, poo#201363

use Mojo::Base 'consoletest';
use testapi;
use utils;
use audit_test;
use Utils::Architectures;
use lockapi;
use network_utils 'iface';
use package_utils 'install_package';
use security::cc_ipsec;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # With strongSwan older than 6.0, the strongswan package also provides the 'ipsec' starter
    install_package('strongswan iputils audit make', trup_reboot => 1);

    my ($server_ip, $client_ip) = ipsec_peer_ips();

    # We don't run setup_multimachine in s390x, so we add the address ourselves
    add_ipsec_mm_ip($client_ip, iface) if is_s390x;

    assert_script_run("cd $audit_test::test_dir/ipsec_configuration/toe");
    mutex_wait('IPSEC_SERVER_READY');

    # Setup the ipip tunnel to the IPSec gateway and test it
    # 192.168.100.1 is configured in the server by ipsec_setup_tunnel_server.sh
    # We need to check if it's accessible to find the network issue easily.
    assert_script_run("./ipsec_setup_tunnel_toe.sh start $client_ip $server_ip");
    script_retry('ping -W1 -c1 192.168.100.1', retry => 10, delay => 10);

    # Install IPSec configuration
    assert_script_run('make install');

    # Test the IPSec connection
    assert_script_run('ipsec start');
    # validate_script_output runs the command in a new shell, thus keep the time in Perl
    my $stime = script_output("date +'%H:%M:%S'");

    # ipsec start returns before charon has loaded the connection
    wait_ipsec_conn('ikev2suse');

    my $up = script_output('ipsec up ikev2suse 2>&1', timeout => is_s390x ? 300 : 90);

    # Test that the CHILD_SA protects the traffic
    my ($vip) = $up =~ /installing new virtual IP (\S+)/;
    my ($ok, $message) = check_ipsec_traffic('ikev2suse', $vip);
    record_info('IPsec traffic', $message, result => $ok ? 'ok' : 'fail');
    die "The IPsec connection does not work\n" unless $ok;

    # The kernel must audit both the new security policies and the new SAs
    validate_script_output("ausearch -m MAC_IPSEC_EVENT -ts $stime", sub { m/op=SPD-add/ && m/op=SAD-add/ });

    $stime = script_output("date +'%H:%M:%S'");

    my $timeout = is_s390x() ? 180 : 90;
    assert_script_run('ipsec down ikev2suse', $timeout);

    # The kernel must audit the deletion of the security policies and SAs
    validate_script_output("ausearch -m MAC_IPSEC_EVENT -ts $stime", sub { m/op=SPD-delete/ && m/op=SAD-delete/ });

    # Stop the IPSec service
    assert_script_run('ipsec stop');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
