# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:test_so_rcv.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::test_so_rcv_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test prints its name and status together on one line, e.g.:

  # Rcv test OK for SO_RCVPRIORITY, IPv4
  # Rcv test FAILED for SO_RCVPRIORITY, IPv4

Lines that do not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*Rcv test (OK|FAILED) for (.*)$/i) {
        my ($st, $description) = (uc $1, $2);
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'OK';
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
