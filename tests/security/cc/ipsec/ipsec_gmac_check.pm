# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check on the IPsec server why the ESP AES-GMAC case fails
#          In FIPS mode the kernel disables rfc4543(gcm(aes)), thus
#          ipsec_ciphers expects the ESP AES-GMAC case to fail. A server with
#          proposals that do not match gives the same result on the client.
#          Make sure in the server journal that the server selected the GMAC
#          proposal and the kernel refused it. This is a separate module
#          because ipsec_server is fatal, and a failure there would also stop
#          the ipsec_certificate cases on both sides. The CC security target
#          does not claim AES-GMAC for ESP, see poo#210543.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#201363, poo#210543

use Mojo::Base 'consoletest';
use testapi;
use security::cc_ipsec;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    if (script_output('cat /proc/sys/crypto/fips_enabled', proceed_on_failure => 1) !~ /^\s*1\s*$/) {
        record_info('No FIPS', 'FIPS mode is disabled, ipsec_ciphers expects the ESP AES-GMAC case to pass');
        return;
    }

    my $log = script_output("journalctl -b --no-pager -o cat -u strongswan | grep -E 'selected proposal: ESP:|received netlink error:' || true");
    if (gmac_refused_by_kernel($log)) {
        record_info('GMAC refused', "The server selected ESP AES-GMAC and the kernel refused it\n\n$log");
    }
    else {
        record_info('GMAC', "The server log does not show that the kernel refused ESP AES-GMAC\n\n$log", result => 'fail');
        $self->result('fail');
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_ipsec_diagnostics();
}

1;
