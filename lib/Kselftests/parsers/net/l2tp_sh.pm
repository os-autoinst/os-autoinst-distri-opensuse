# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:l2tp.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::l2tp_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\s*TEST:\s+(.*?)\s+\[\s*(OK|FAIL|SKIP|XFAIL|XPASS|ERROR|WARN)\s*\]\s*$/i) {
        my ($description, $st) = ($1, uc $2);
        my $normalized;
        if ($st eq 'OK' or $st eq 'XPASS') {
            $normalized = "# ok $test_idx $description";
        }
        elsif ($st eq 'SKIP') {
            $normalized = "# ok $test_idx $description # SKIP";
        }
        elsif ($st eq 'XFAIL') {
            $normalized = "# ok $test_idx $description # TODO Expected failure";
        }
        else {
            #FAIL / ERROR / WARN
            $normalized = "# not ok $test_idx $description";
        }
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
