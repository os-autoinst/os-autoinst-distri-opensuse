# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the cgroup collection
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::cgroup;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

The cgroup selftests print a diagnostic line before a failed subtest result,
for example the line from values_close_report():

  # [FAIL] actual=18722816 expected=30408704 | diff=11685888 | ...
  # not ok 3 test_memcg_min

openQA shows only the result line in the subtest box. This parser keeps
the diagnostic lines and appends them to the next C<not ok> result line:

  # not ok 3 test_memcg_min # [FAIL] actual=18722816 expected=30408704 | ...

The subtest name stays in front of the first C<#>, so the openQA box title
and the known issues lookup do not change. All other lines are returned
unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s?(\[FAIL\]\s.*)$/) {
        push(@{$self->{diagnostics}}, $1);
    } elsif ($ln =~ /^#\s?(not\s)?ok\s\d+\s/) {
        my $failed = defined($1);
        my @diagnostics = @{$self->{diagnostics} // []};
        $self->{diagnostics} = [];
        return join(' # ', $ln, @diagnostics) if $failed && @diagnostics;
    }
    return $test_ln;
}

1;
