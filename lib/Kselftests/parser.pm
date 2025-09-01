# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: KTAP post-processing parser factory
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parser;

use Kselftests::parsers::main;

use Kselftests::parsers::net::l2tp_sh;

use Kselftests::parsers::livepatch;

use Kselftests::parsers::bpf::test_bpftool_sh;
use Kselftests::parsers::bpf::test_lru_map;
use Kselftests::parsers::bpf::test_maps;
use Kselftests::parsers::bpf::test_progs;
use Kselftests::parsers::bpf::test_progs_cpuv4;
use Kselftests::parsers::bpf::test_progs_no_alu32;
use Kselftests::parsers::bpf::test_sockmap;
use Kselftests::parsers::bpf::test_tag;
use Kselftests::parsers::bpf::test_tc_edt_sh;
use Kselftests::parsers::bpf::test_tc_tunnel_sh;
use Kselftests::parsers::bpf::test_tcpnotify_user;
use Kselftests::parsers::bpf::test_verifier;
use Kselftests::parsers::bpf::test_xdping_sh;
use Kselftests::parsers::bpf::test_xsk_sh;

use testapi;
use strict;
use warnings;

sub factory {
    my ($collection, $sanitized_test_name) = @_;
    my $obj;
    eval {
        my $pkg = "Kselftests::parsers::${collection}::${sanitized_test_name}";
        $obj = $pkg->new();
    } or eval {
        my $pkg = "Kselftests::parsers::${collection}";
        $obj = $pkg->new();
    } or do {
        $obj = Kselftests::parsers::main->new();
    };
    return $obj;
}

1;
