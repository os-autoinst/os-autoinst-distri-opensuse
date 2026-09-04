# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_xdping.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_xdping_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\sTest\s(.*):\s(PASS)$/) {
        my $diagnostic = $1;
        my $normalized = "# ok $test_idx # $diagnostic";
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
