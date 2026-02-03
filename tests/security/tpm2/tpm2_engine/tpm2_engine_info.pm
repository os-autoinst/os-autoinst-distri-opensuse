# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will show
#          the engine info.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use Utils::Systemd 'systemctl';

sub run {
    select_serial_terminal;

    # Ensure the resource manager daemon is healthy if required
    systemctl 'is-active tpm2-abrmd';

    if (is_sle('<15-SP6')) {
        validate_script_output 'openssl engine -t -c tpm2tss', sub { m/^\(tpm2tss\)\s+TPM2-TSS engine for OpenSSL/m; };
    } else {
        # Test the modern TPM2 provider
        my $output = script_output('openssl list -providers');
        die "default provider missing\n" unless $output =~ /^\s*default\n/m;
        die "default provider name wrong or missing\n" unless $output =~ /^\s+name:\s+OpenSSL Default Provider/m;
        die "default provider not active\n" unless $output =~ /^\s+status:\s+active/m;
    }
}

1;
