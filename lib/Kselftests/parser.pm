# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: KTAP post-processing parser factory
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parser;

use Kselftests::parsers::main;
use Kselftests::parsers::net::l2tp_sh;

use testapi;
use strict;
use warnings;

sub factory {
    my ($collection, $sanitized_test_name) = @_;
    my $obj;
    eval {
        my $pkg = "Kselftests::parsers::${collection}::${sanitized_test_name}";
        $obj = $pkg->new();
    } or do {
        $obj = Kselftests::parsers::main->new();
    };
    return $obj;
}

1;
