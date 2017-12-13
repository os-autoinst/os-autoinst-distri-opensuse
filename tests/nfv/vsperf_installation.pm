# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: VSPerf tool installation
#
#   This test does the following
#    - Installs git to clone vswitchperf repo
#    - Fetches the non-merged patch to support SLES15
#    - Removes the lines to skip OVS, DPDK and QEMU compilation
#    - Executes the script to install all the needed packages for VSPerf
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "consoletest";
use testapi;
use strict;
use utils;

sub run {
    my $vsperf_repo = "https://gerrit.opnfv.org/gerrit/vswitchperf";

    select_console 'root-console';

    zypper_call('in git-core', timeout => 200);

    # Clone repository
    assert_script_run "git clone $vsperf_repo";
    assert_script_run "cd vswitchperf/systems";

    # Checkout the patch supporting SLE15 (to be removed once the patch is merged upstream)
    assert_script_run "git fetch $vsperf_repo refs/changes/17/48017/3 && git checkout FETCH_HEAD";

    # Hack to skip the OVS, DPDK and QEMU compilation as SLE15 will use the vanilla packages
    assert_script_run "sed -n -e :a -e '1,8!{P;N;D;};N;ba' -i build_base_machine.sh";

    # Vsperf packages installation
    assert_script_run("bash -x build_base_machine.sh", 300);
}

1;

# vim: set sw=4 et:
