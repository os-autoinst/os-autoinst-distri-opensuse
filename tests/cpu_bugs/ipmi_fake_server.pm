# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create fake server to occupy worker
# openQA scheduler cannot deal with test suites which on differents workers,
# use locking API to workaround test sequence in job group.

# Maintainer: An Long <lan@suse.com>

use warnings;
use strict;
use base "opensusebasetest";
use testapi;
use utils;
use lockapi;
use mmapi;

sub run {
    # unlock by creating the lock
    mutex_create 'qemu_worker_ready';

    # wait until all children finish
    wait_for_children;
}

1;
