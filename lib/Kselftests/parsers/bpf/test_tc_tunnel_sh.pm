# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the bpf:test_tc_tunnel.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::bpf::test_tc_tunnel_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

our $test_idx = 1;
our %cur;

sub parse_line {
    my ($self, $test_ln) = @_;
    if ($test_ln =~ /^#\stest\s(.*?)(?:\s*\((expect failure)\))?$/) {
        $cur{description} = $1;
        $cur{expect_failure} = $2;
    } elsif ($test_ln =~ /^#\s([0-1])$/) {
        my $st = $1;
        my $normalized;
        if ($cur{expect_failure}) {
            if ($st) {
                $normalized = "# ok $test_idx $cur{description}";
            } else {
                $normalized = "# not ok $test_idx $cur{description}";
            }
        } else {
            if ($st) {
                $normalized = "# not ok $test_idx $cur{description}";
            } else {
                $normalized = "# ok $test_idx $cur{description}";
            }
        }
        $test_idx++;
        return $normalized;
    }
    return undef;
}

1;
