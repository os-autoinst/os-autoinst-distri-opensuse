# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_lru_map selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_lru_map;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;

sub parse_line {
    my ($self, $test_ln) = @_;
    my $normalized;
    if ($test_ln =~ /^#\s(\S+)\s\((.*)\):\sPass$/) {
        my ($description, $diagnostic) = ($1, $2);
        $normalized = "# ok $test_idx $description # ($diagnostic)";
        $test_idx++;
        return $normalized;
    } elsif ($test_ln =~ /^#\s(\S+)\s\((.*)\):\s(.*)$/) {
        my ($description, $d1, $d2) = ($1, $2, $3);
        $normalized = "# not ok $test_idx $description # ($d1) - $d2";
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
