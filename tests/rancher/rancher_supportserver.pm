# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup multimachine barriers as supportserver is the parent task
# Maintainer: Pavel Dostal <pdostal@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_network;
use Utils::Systemd 'disable_and_stop_service';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
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

