# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Mellanox OFED package installation
# This package is not ready for SLE15 yet, there is an available
# package for SLE12-SP3 which is able to build the needed RPMs
# on SLE15.
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run {
    select_console 'root-ssh';
    my $ofed_url      = get_required_var('OFED_URL');
    my $ofed_file_tgz = (split(/\//, $ofed_url))[-1];
    my $ofed_dir      = ((split(/\.tgz/, $ofed_file_tgz))[0]);

    zypper_call('--quiet in openvswitch python-devel python2-libxml2-python libopenssl1_0_0 insserv-compat libstdc++6-devel-gcc7 createrepo_c', timeout => 500);

    # Install Mellanox OFED
    assert_script_run("wget $ofed_url");
    assert_script_run("tar -xvf $ofed_file_tgz");
    assert_script_run("cd $ofed_dir");
    assert_script_run("./mlnxofedinstall --skip-distro-check --add-kernel-support", timeout => 500);
    assert_script_run("modprobe -rv rpcrdma");
    assert_script_run("/etc/init.d/openibd restart");

}

sub test_flags {
    return {fatal => 1};
}

1;

