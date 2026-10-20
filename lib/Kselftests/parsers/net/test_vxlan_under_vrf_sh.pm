# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:test_vxlan_under_vrf.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::test_vxlan_under_vrf_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

test_vxlan_under_vrf.sh prints each description with 'echo -n', then
appends the status on the same line, e.g.:

  # Checking HV connectivity                                           [ OK ]

Lines that do not match this format are returned unchanged. A SKIP
status is left untouched rather than converted (see net.pm).

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(\S.*?)\s+\[\s*(OK|PASS|FAIL|SKIP|XFAIL|XPASS|ERROR)\s*\]$/i) {
        my ($description, $st) = ($1, uc $2);
        return $test_ln if $st eq 'SKIP';
        my $idx = ++$self->{idx};
        if ($st eq 'OK' or $st eq 'PASS' or $st eq 'XPASS') {
            return "# ok $idx $description";
        } elsif ($st eq 'XFAIL') {
            return "# ok $idx $description # TODO Expected failure";
        }
        # FAIL / ERROR
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
