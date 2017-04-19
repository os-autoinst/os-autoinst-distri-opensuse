# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: prepare environment for HPC module testing
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;

sub run() {
    # current structure of HPC tests in sle/main.pm make it easiest way to skip this module for HPC=repository
    return if check_var('HPC', 'repository');
    barrier_wait('NODES_STARTED');
    barrier_wait('NETWORK_READY');
    # hpc channels
    my $repo = get_required_var('HPC_REPO');
    select_console('root-console');
    assert_script_run('systemctl stop SuSEfirewall2');
    pkcon_quit();
    zypper_call("ar -f $repo SLE-Module-HPC");
    if (my $openhpc_repo = get_var("OPENHPC_REPO")) {
        zypper_call("ar -f $openhpc_repo OPENHPC_REPO");
    }
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('up');
    save_screenshot;
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
