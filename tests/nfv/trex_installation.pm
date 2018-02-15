# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Trex traffic generator installation
#
#   This test does the following
#    - Clones Trex from official repo
#    - Follow installation steps described in https://github.com/cisco-system-traffic-generator/trex-core/wiki
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "consoletest";
use testapi;
use strict;
use utils;
use mmapi;

sub run {
    my $trex_repo = "https://github.com/cisco-system-traffic-generator/trex-core.git";
    my $trex_dest = "/tmp/trex-core";

    select_console 'root-console';

    zypper_call('in git-core gcc gcc-c++ make cmake libnuma-devel kernel-source pciutils', timeout => 300);

    # Clone Trex repository
    assert_script_run("git clone --depth 1 $trex_repo $trex_dest", timeout => 500);

    # Copy sample config file to default localtion
    assert_script_run("cp $trex_dest/scripts/cfg/simple_cfg.yaml /etc/trex_cfg.yaml");

    # Compile Trex libraries
    assert_script_run("cd $trex_dest/linux_dpdk");
    assert_script_run("./b configure", 300);
    assert_script_run("./b build",     1200);
}

1;

# vim: set sw=4 et: