# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_xsk.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_xsk_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\s(?<status>ok|not ok)?\s(?<idx>\d+)\s(?:PASS|FAIL):\s(?<mode>\S*)\s(?<subtest>\S*)$/) {
        my ($status, $idx, $mode, $subtest) = @+{qw(status idx mode subtest)};
        return "# $status $idx ${mode}_${subtest}";
    } elsif ($test_ln =~ /SKIP/) {
        return $test_ln;
    }
    return undef;
}

1;
