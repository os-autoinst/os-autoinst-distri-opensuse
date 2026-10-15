# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:reuseport_addr_any.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::reuseport_addr_any_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

The reuseport_addr_any binary prints its description and status on
one line, e.g.:

  # UDP IPv4 ... pass

A failure aborts the binary, so only 'pass' is ever printed. Lines
that do not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(\S.*?)\s*\.\.\.\s*pass$/i) {
        my $description = $1;
        my $idx = ++$self->{idx};
        return "# ok $idx $description";
    }
    return $test_ln;
}

1;
