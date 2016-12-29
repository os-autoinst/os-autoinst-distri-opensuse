# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run() {
    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-slave');

    zypper_call('in munge libmunge2');
    barrier_wait('MUNGE_INSTALLED');
    barrier_wait('MUNGE_KEY_COPY');
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    barrier_wait('MUNGE_SERVICE_START');
    barrier_wait('TEST_END');
}

1;

# vim: set sw=4 et:

