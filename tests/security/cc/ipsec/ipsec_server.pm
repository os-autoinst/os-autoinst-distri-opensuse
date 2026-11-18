# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'ipsec' server case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101226, poo#201363

use Mojo::Base 'consoletest';
use testapi;
use utils;
use audit_test;
use Utils::Architectures;
use lockapi;
use mmapi 'get_children';
use network_utils 'iface';
use package_utils 'install_package';
use security::cc_ipsec;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    install_package('strongswan iputils make', trup_reboot => 1);

    my ($server_ip, $client_ip) = ipsec_peer_ips();

    # We don't run setup_multimachine in s390x, so we add the address ourselves
    add_ipsec_mm_ip($server_ip, iface) if is_s390x;

    assert_script_run("cd $audit_test::test_dir/ipsec_configuration/server");

    # Create ipip tunnel to the TOE system
    assert_script_run("./ipsec_setup_tunnel_server.sh start $server_ip $client_ip");

    # Install IPSec configuration
    assert_script_run('make install');

    # Accept also the proposals of the client cases, so that each case is
    # decided where it should be. For example the weak ESP case must reach the
    # CHILD_SA negotiation, thus the server must accept its IKE proposal.
    my $conf = '/etc/swanctl/conf.d/ikev2suse.conf';
    my $ike_proposals = ',aes256ctr-sha256-modp2048,aes128ctr-sha256-modp6144,aes256ccm8-prfsha256-modp3072';
    my $esp_proposals = ',aes128-sha512-modp2048,aes192gmac-modp2048,aes256-sha256-modp2048';
    assert_script_run("sed -i '/ proposals = / s/\$/$ike_proposals/' $conf");
    assert_script_run("sed -i '/ esp_proposals = / s/\$/$esp_proposals/' $conf");
    script_run("cat $conf");

    # Start StrongSWAN
    assert_script_run('systemctl start strongswan');

    mutex_create('IPSEC_SERVER_READY');

    # The client creates this mutex after the ipsec_ciphers cases
    my $children = get_children();
    mutex_wait('IPSEC_CLIENT_DONE', (keys %$children)[0]);

    # Only the server logs show why it rejected a client case, upload them
    # also when all the cases pass
    upload_ipsec_diagnostics();

    # In FIPS mode the client expects the ESP AES-GMAC case to fail, because the
    # kernel disables rfc4543(gcm(aes)). Make sure that this is the reason, and
    # not proposals that do not match.
    if (script_output('cat /proc/sys/crypto/fips_enabled', proceed_on_failure => 1) =~ /^\s*1\s*$/) {
        validate_script_output("journalctl -b --no-pager -u strongswan | grep -A3 'selected proposal: ESP:NULL_AES_GMAC_192' || true",
            sub { m/selected proposal: ESP:NULL_AES_GMAC_192/ && m/Requested AEAD algorithm not found/ });
    }

    # Stop StrongSWAN
    assert_script_run('systemctl stop strongswan');

    # Delete ipip tunnel
    assert_script_run('./ipsec_setup_tunnel_server.sh stop');
}

sub test_flags {
    # The client waits for IPSEC_SERVER_READY and cannot do anything without the
    # server. Stop the job on failure, then openQA cancels the client at once.
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
