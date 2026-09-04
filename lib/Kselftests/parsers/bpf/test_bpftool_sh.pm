# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_bpftool.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_bpftool_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\s(\S+)\s\((.*)\)\s...\s(ok|FAIL)$/) {
        my ($description, $diagnostic, $st) = ($1, $2, $3);
        my $normalized;
        if ($st eq 'ok') {
            $normalized = "# ok $test_idx $description # $diagnostic";
        } else {
            $normalized = "# not ok $test_idx $description # $diagnostic";
        }
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
