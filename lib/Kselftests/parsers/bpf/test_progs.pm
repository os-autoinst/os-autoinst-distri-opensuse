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
    if ($test_ln =~ /(?:^#\s)?#\S+\s+(\S+):(OK|FAIL|SKIP)$/) {
        my ($description, $st) = ($1, $2);
        my $normalized;
        if ($st eq 'FAIL') {
            $normalized = "# not ok $test_idx $description";
        } elsif ($st eq 'OK') {
            $normalized = "# ok $test_idx $description";
        } else {
            $normalized = "# ok $test_idx $description # SKIP";
        }
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
