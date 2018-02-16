# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Moongen traffic generator installation
#
#   This test does the following
#    - Install needed dependencies for MoonGenn tool
#    - Installs git to clone MoonGen repo
#    - Follow installation steps described in https://github.com/emmericp/MoonGen
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use strict;
use utils;
use mmapi;
use serial_terminal 'select_virtio_console';

sub run {
    my $moongen_repo = "https://github.com/emmericp/MoonGen.git";

    select_virtio_console();

    zypper_call('in git-core gcc gcc-c++ make cmake libnuma-devel kernel-source pciutils', timeout => 300);

    # Clone repository
    assert_script_run("git clone --depth 1 $moongen_repo", timeout => 300);

    # Install MoonGen and dependencies
    assert_script_run("cd MoonGen");
    assert_script_run("bash -x build.sh",           500);
    assert_script_run("bash -x setup-hugetlbfs.sh", 300);
    assert_script_run("bash -x bind-interfaces.sh", 300);
}

1;

# vim: set sw=4 et:
