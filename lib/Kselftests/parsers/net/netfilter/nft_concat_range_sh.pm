# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net/netfilter:nft_concat_range.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::netfilter::nft_concat_range_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

nft_concat_range.sh groups its subtests under category headers, and
prints each result with a duration instead of the usual 'TEST:'
prefix, for example:

  # TEST: correctness
  #   net,port                              1s                              [ OK ]
  #   port,net                              0s                              [ OK ]

The category is kept and prepended to the subtest name (e.g.
'correctness: net,port'), since the same name is reused across
categories (e.g. 'reported issues', 'correctness', 'concurrency' and
'timeout'). Lines that do not match this format are returned
unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*TEST:\s*(.*)$/) {
        $self->{category} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s+(.*?)\s+\d+s\s+\[\s*(OK|FAIL|SKIP|XFAIL|XPASS|ERROR|WARN)\s*\]$/i) {
        my ($description, $st) = ($1, uc $2);
        return $test_ln if $st eq 'SKIP';
        $description = "$self->{category}: $description" if $self->{category};
        my $idx = ++$self->{idx};
        if ($st eq 'OK' or $st eq 'XPASS') {
            return "# ok $idx $description";
        } elsif ($st eq 'XFAIL') {
            return "# ok $idx $description # TODO Expected failure";
        }
        # FAIL / ERROR / WARN
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
