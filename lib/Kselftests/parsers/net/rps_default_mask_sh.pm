# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:rps_default_mask.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::rps_default_mask_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test's chk_rps() helper prints a description padded with
'printf', then appends the status on the same line, e.g.:

  # empty rps_default_mask                                     [ ok ]
  # changing rps_default_mask doesn't affect existing devices   [fail] expected 1 found 0

The whole test is skipped outright on systems with 2 CPUs or fewer,
in which case none of this is ever printed. Lines that do not match
this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(\S.*?)\s*\[\s*(ok|fail)\s*\]\s*(.*)$/i) {
        my ($description, $st, $extra) = ($1, lc $2, $3);
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'ok';
        $description .= ": $extra" if length $extra;
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
