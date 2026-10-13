# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: KTAP post-processing parser factory
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parser;

use Kselftests::parsers::main;

use Kselftests::parsers::net;
use Kselftests::parsers::net::arp_ndisc_evict_nocarrier_sh;
use Kselftests::parsers::net::route_localnet_sh;
use Kselftests::parsers::net::io_uring_zerocopy_tx_sh;
use Kselftests::parsers::net::ip_defrag_sh;
use Kselftests::parsers::net::ipv6_flowlabel_sh;
use Kselftests::parsers::net::l2tp_sh;
use Kselftests::parsers::net::run_afpackettests;
use Kselftests::parsers::net::run_netsocktests;
use Kselftests::parsers::net::sctp_vrf_sh;
use Kselftests::parsers::net::test_so_rcv_sh;
use Kselftests::parsers::net::udpgro_sh;
use Kselftests::parsers::net::udpgro_fwd_sh;
use Kselftests::parsers::net::veth_sh;
use Kselftests::parsers::net::test_vxlan_under_vrf_sh;
use Kselftests::parsers::net::test_vxlan_fdb_changelink_sh;

use Kselftests::parsers::livepatch;

use Kselftests::parsers::cgroup;

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
    (my $pkg_collection = $collection) =~ s{/}{::}g;
    (my $top_collection = $collection) =~ s{/.*}{};
    eval {
        my $pkg = "Kselftests::parsers::${pkg_collection}::${sanitized_test_name}";
        $obj = $pkg->new();
    } or eval {
        my $pkg = "Kselftests::parsers::${pkg_collection}";
        $obj = $pkg->new();
    } or eval {
        # Subcollections (e.g. 'net/forwarding') fall back to the parser of
        # their top-level collection (e.g. 'net') when they don't have one
        # of their own.
        my $pkg = "Kselftests::parsers::${top_collection}";
        $obj = $pkg->new();
    } or do {
        $obj = Kselftests::parsers::main->new();
    };
    return $obj;
}

1;
