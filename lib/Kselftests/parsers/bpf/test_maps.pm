# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_maps selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_maps;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\s(\S+)+:(PASS|FAIL)$/) {
        my ($description, $st) = ($1, $2);
        my $normalized;
        if ($st eq 'PASS') {
            $normalized = "# ok $test_idx $description";
        } else {
            $normalized = "# not ok $test_idx $description";
        }
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
