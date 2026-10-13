# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:ip_defrag.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::ip_defrag_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test echoes a description before running the ip_defrag binary
for each case, e.g.:

  # ipv4 defrag
  # seed = 1791903594
  # PASS

A failure would abort the binary without printing 'PASS', so only the
success case is recognized. The subtest name from the last
'ipv4|ipv6 ...' line is kept and used once the bare 'PASS' line shows
up. Lines that do not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(ipv[46]\b.*)$/i) {
        $self->{pending} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s*PASS\s*$/i) {
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        return "# ok $idx $description";
    }
    return $test_ln;
}

1;
