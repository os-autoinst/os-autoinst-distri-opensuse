# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: standard installation
#    This test is as simple as it can be at the moment, since we are at the very
#    beginning of HPC testing
#    It only adds the repo and installs the four important packages to check if there are any
#    dependency issues
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    select_console('root-console');

    pkcon_quit();
    # install slurm
    zypper_call('in slurm-munge');
    zypper_call('up');

}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
