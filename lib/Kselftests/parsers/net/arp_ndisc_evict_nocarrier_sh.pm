# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:arp_ndisc_evict_nocarrier.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::arp_ndisc_evict_nocarrier_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test (and route_localnet.sh) announce a subtest with
'echo "run NAME test"', then print a bare 'ok' or 'failed' on its own
line once it is done, e.g.:

  # run arp_evict_nocarrier=1 test
  # ok

The subtest name from the last 'run ... test' line is kept and used
once the bare status line shows up. Lines that do not match this
format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*run\s+(.*?)\s+test\s*$/i) {
        $self->{pending} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s*(ok|failed)\s*$/i) {
        my $st = lc $1;
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'ok';
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
