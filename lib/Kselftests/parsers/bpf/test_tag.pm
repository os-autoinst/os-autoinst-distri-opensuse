# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_tag selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_tag;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\s\S+:\sOK\s(.*)$/) {
        my $n = $1;
        return "# ok 1 test_tag # $n";
    } else {
        return $test_ln;
    }
}

1;
