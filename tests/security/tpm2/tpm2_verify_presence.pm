# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test that TPM is present and is working fine.
#
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use serial_terminal 'select_serial_terminal';
use testapi;


sub run {
    select_serial_terminal;

    my $out = script_output('fdectl tpm-present', proceed_on_failure => 1);
    record_info('TPM output', $out);

    die 'TPM self-test failed'
      unless $out =~ /TPM self test succeeded/i;

    die 'TPM seal/unseal failed'
      unless $out =~ /TPM seal\/unseal works/i;

    record_info('TPM', 'TPM is present and working');
}

sub test_flags {
    return {fatal => 1};
}

1;
