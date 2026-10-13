# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net/netfilter:nf_conntrack_packetdrill.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::netfilter::nf_conntrack_packetdrill_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test prints a description with 'printf' (no trailing newline),
then runs packetdrill, whose own diagnostics (if any) land on the
same line and on following lines, before a bare 'OK' or 'FAIL' marks
the actual verdict, e.g.:

  # packetdrill/conntrack_syn_challenge_ack.pkt       (ipv4)                    packetdrill/conntrack_syn_challenge_ack.pkt:38: warning handling packet: ...
  # script packet:  0.223897 . 1:1(0) ack 1 win 256 <nop,nop,TS val 1 ecr 1>
  # actual packet:  0.213892 . 1:1(0) ack 1 win 1050 <nop,nop,TS val 115 ecr 1>
  # OK

or, with no diagnostics, directly on one line:

  # packetdrill/conntrack_ack_loss_stall.pkt          (ipv4)                    OK

The subtest name from the last 'packetdrill/... (ipvN)' prefix is
kept and used once the bare 'OK'/'FAIL' line shows up. Lines that do
not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(packetdrill\/\S+\s*\(ipv[46]\))\s*(OK|FAIL)\s*$/i) {
        my ($description, $st) = ($1, uc $2);
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'OK';
        return "# not ok $idx $description";
    }
    if ($ln =~ /^#\s*(packetdrill\/\S+\s*\(ipv[46]\))/i) {
        $self->{pending} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s*(OK|FAIL)\s*$/i) {
        my $st = uc $1;
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'OK';
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
