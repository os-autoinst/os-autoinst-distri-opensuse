# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openvswitch python-devel python2-libxml2-python libopenssl1_1
# insserv-compat libstdc++6-devel-gcc7 createrepo_c rpm python-libxml2
# libopenssl1_0_0 libstdc++-devel createrepo rpm-build kernel-syms tk
# Summary: Mellanox OFED package installation
# This package is not ready for SLE15 yet, there is an available
# package for SLE12-SP3 which is able to build the needed RPMs
# on SLE15.
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    select_serial_terminal;

    my $ofed_url = get_required_var('OFED_URL');
    my $ofed_file_tgz = (split(/\//, $ofed_url))[-1];
    my $ofed_dir = ((split(/\.tgz/, $ofed_file_tgz))[0]);

    if (is_sle('>=15')) {
        zypper_call('--quiet in openvswitch python-devel python2-libxml2-python libopenssl1_1 insserv-compat libstdc++6-devel-gcc7 createrepo_c rpm', timeout => 500);
    }
    elsif (check_var('VERSION', '12-SP4')) {
        zypper_call("--quiet ar -f http://download.suse.de/ibs/SUSE:/SLE-12-SP4:/GA:/TEST/images/repo/SLE-12-SP4-SDK-POOL-x86_64-Media1/ SLE-12-SP4-SDK-POOL1");
        zypper_call('--quiet in openvswitch python-devel python-libxml2 libopenssl1_0_0 insserv-compat libstdc++-devel createrepo rpm-build kernel-syms tk', timeout => 500);
    }
    else {
        die "OS VERSION not supported. Available only on >=15 and 12-SP4";
    }

    # Install Mellanox OFED
    assert_script_run("wget $ofed_url");
    assert_script_run("tar -xvf $ofed_file_tgz");
    assert_script_run("cd $ofed_dir");
    if (is_ipmi) {
        record_info('INFO', 'OFED install');
        assert_script_run("./mlnxofedinstall --skip-distro-check --add-kernel-support --with-mft --with-mstflint --dpdk --upstream-libs", timeout => 2000);
        assert_script_run("modprobe -rv rpcrdma");
        assert_script_run("/etc/init.d/openibd restart");
        script_run("ibv_devinfo");
        script_run("ibdev2netdev");
        script_run("ofed_info -s");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
