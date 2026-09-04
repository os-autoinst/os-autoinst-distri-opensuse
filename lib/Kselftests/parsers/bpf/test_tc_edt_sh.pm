# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_tc_edt.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_tc_edt_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /# PASS/) {
        return "# ok 1 test_tc_edt";
    } elsif ($test_ln =~ /# FAIL/) {
        return "# not ok 1 test_tc_edt";
    }
    return undef;
}

1;
