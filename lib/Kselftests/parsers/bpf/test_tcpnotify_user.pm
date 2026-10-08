# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_tcpnotify_user selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_tcpnotify_user;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /# PASSED!/) {
        return "# ok 1 test_tcpnotify_user";
    } elsif ($test_ln =~ /# FAILED:/) {
        return "# not ok 1 test_tcpnotify_user";
    }
    return undef;
}

1;
