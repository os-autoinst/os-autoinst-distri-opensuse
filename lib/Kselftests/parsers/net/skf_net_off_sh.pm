# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:skf_net_off.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::skf_net_off_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test echoes a description, then runs the skf_net_off binary,
which only ever prints one of three fixed diagnostic lines before a
bare 'OK', e.g.:

  # filter, fragmented skb (-f) (-F)
  # bpf filter enabled
  # napi frags mode enabled
  # raw recv: 0xabababab
  # OK

A one-time 'net.ipv4.ip_early_demux = 0' line (from the sysctl call
before the first case) is excluded the same way. Any other line is
assumed to be the pending description for the next 'OK'. Lines that
do not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;
    (my $content = $ln) =~ s/^#\s*//;

    if ($content =~ /^OK$/i) {
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        return "# ok $idx $description";
    }
    if ($content =~ /^bpf filter enabled$/i
        or $content =~ /^napi frags mode enabled$/i
        or $content =~ /^raw recv:/i
        or $content =~ /^net\.\w+\.\w+ = \d+$/) {
        return $test_ln;
    }
    $self->{pending} = $content if length $content;
    return $test_ln;
}

1;
