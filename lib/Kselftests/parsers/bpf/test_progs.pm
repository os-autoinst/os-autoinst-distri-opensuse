# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_progs selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_progs;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;

sub parse_line {
    my ($self, $test_ln) = @_;
    my ($description, $st, $test_name, $diag);
    if ($test_ln =~ /^#\s#\S+\s+(\S+):(OK|FAIL|SKIP)$/) {
        ($description, $st) = ($1, $2);
    } elsif ($test_ln =~ /^#\s(\S*?):(PASS|SKIP|FAIL):(\S*?)\s(.*)$/) {
        ($description, $st, $test_name, $diag) = ($1, $2, $3, $4);
    }
    if ($description) {
        if ($test_name) {
            $description .= "/$test_name";
        }
        my $normalized;
        if ($st eq 'PASS') {
            $normalized = "# ok $test_idx $description";
        } elsif ($st eq 'FAIL') {
            $normalized = "# not ok $test_idx $description";
        } else {
            $normalized = "# ok $test_idx $description # SKIP";
        }
        if ($diag) {
            $normalized .= " # $diag";
        }
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
