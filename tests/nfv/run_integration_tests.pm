# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Executes all the integration tests to verify that
# vsperf can control openvswitch properly
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use mmapi;

sub run {
    my $self = shift;
    my $vsperf_conf = "/etc/vsperf_ovs.conf";

    select_serial_terminal;

    # use conf file from data dir
    assert_script_run("curl " . data_url('nfv/vsperf_ovs_dummy.conf') . " -o $vsperf_conf");

    # source environment
    assert_script_run('source /root/vsperfenv/bin/activate');

    # run integration tests
    assert_script_run('cd /root/vswitchperf/');
    assert_script_run('./vsperf --conf-file=' . $vsperf_conf . ' --integration vswitch_add_del_bridge');
    assert_script_run('./vsperf --conf-file=' . $vsperf_conf . ' --integration vswitch_add_del_bridges');
    assert_script_run('./vsperf --conf-file=' . $vsperf_conf . ' --integration vswitch_add_del_vport');
    assert_script_run('./vsperf --conf-file=' . $vsperf_conf . ' --integration vswitch_add_del_vports');
    assert_script_run('./vsperf --conf-file=' . $vsperf_conf . ' --integration vswitch_vports_add_del_flow');

    wait_for_children;
}

1;
