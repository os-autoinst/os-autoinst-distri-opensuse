# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:io_uring_zerocopy_tx.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::io_uring_zerocopy_tx_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test re-invokes itself with the arguments for each combination,
echoing them first, e.g.:

  # ipv4 udp -m 1 -t 1 -n 32
  # cpu: unable to pin, may increase variance.
  # tx=83968 (MB=5239), tx/s=83968 (MB/s=5239)
  # rx=82045 (5119 MB)
  # ok

A failure aborts the script (set -e), so only 'ok' is ever printed.
The subtest name from the last 'ipv4|ipv6 ...' line is kept and used
once the bare 'ok' line shows up. Lines that do not match this format
are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(ipv[46]\s+.*)$/i) {
        $self->{pending} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s*ok\s*$/i) {
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        return "# ok $idx $description";
    }
    return $test_ln;
}

1;
