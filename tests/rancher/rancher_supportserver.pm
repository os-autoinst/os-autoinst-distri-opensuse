# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup multimachine barriers as supportserver is the parent task
# Maintainer: Pavel Dostal <pdostal@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use mm_network;
use Utils::Systemd 'disable_and_stop_service';

sub run {
    select_serial_terminal;
    # All nodes are online with SSH enabled
    barrier_create('networking_prepared', 3);
    # Master node is ready to accept workers
    barrier_create('cluster_prepared', 3);
    # Cluster is fully deployed
    barrier_create('cluster_deployed', 3);
    # Testing is done, cluster can be destroyed
    barrier_create('cluster_test_done', 3);
}

1;

