# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: KTAP post-processing default parser
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::main;

use testapi;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless({}, $class);
}

sub parse_line {
    my ($self, $string) = @_;
    return $string;
}

1;
