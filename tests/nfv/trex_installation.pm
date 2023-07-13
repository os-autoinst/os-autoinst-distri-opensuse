# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Trex traffic generator installation
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;
    my $trex_version = get_required_var('TG_VERSION');
    my $tarball = "$trex_version.tar.gz";
    my $url = "http://trex-tgn.cisco.com/trex/release/$tarball";
    my $trex_dest = "/tmp/trex-core";
    my $trex_conf = "/etc/trex_cfg.yaml";
    my $PORT_1 = get_required_var('PORT_1');
    my $PORT_2 = get_required_var('PORT_2');

    select_serial_terminal;

    # Download and extract T-Rex package
    record_info("INFO", "Download TREX package");
    assert_script_run("wget $url", timeout => 60 * 30);
    assert_script_run("tar -xzf $tarball");
    assert_script_run("mv $trex_version $trex_dest");

    # Copy config file and replace port values
    record_info("INFO", "Modify TREX config file.");
    assert_script_run("curl " . data_url('nfv/trex_cfg.yaml') . " -o $trex_conf");
    assert_script_run("sed -i 's/PORT_0/$PORT_1/' -i $trex_conf");
    assert_script_run("sed -i 's/PORT_1/$PORT_2/' -i $trex_conf");
    assert_script_run("cat $trex_conf");

    if (is_ipmi) {
        record_info("INFO", "Bring Mellanox interfaces up");
        assert_script_run("ip link set dev eth2 up");
        assert_script_run("ip link set dev eth3 up");
    }

    record_info("INFO", "Stop Firewall");
    systemctl 'stop ' . $self->firewall;

    record_info("INFO", "TREX installation & configuration ready. Mutex NFV_TRAFFICGEN_READY created.");
    mutex_create("NFV_TRAFFICGEN_READY");

    record_info("INFO", "Wait for VSPerf installation, wait for Mutex NFV_VSPERF_READY");
    mutex_wait('NFV_VSPERF_READY');
}

1;
