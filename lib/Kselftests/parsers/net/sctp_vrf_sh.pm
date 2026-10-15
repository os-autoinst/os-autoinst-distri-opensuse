# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:sctp_vrf.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::sctp_vrf_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

sctp_vrf.sh does not use net/lib.sh's log_test(); it prints its own
numbered result on one line, e.g.:

  # TEST 01: nobind, connect from client 1, l3mdev_accept=1, Y [PASS]

Lines that do not match this format are returned unchanged. A SKIP
status is left untouched rather than converted (see net.pm).

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*TEST\s+\d+:\s*(.*?)\s*\[\s*(OK|PASS|FAIL|SKIP|XFAIL|XPASS|ERROR|WARN)\s*\]$/i) {
        my ($description, $st) = ($1, uc $2);
        return $test_ln if $st eq 'SKIP';
        my $idx = ++$self->{idx};
        if ($st eq 'OK' or $st eq 'PASS' or $st eq 'XPASS') {
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
