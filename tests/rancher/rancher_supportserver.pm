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
    barrier_create('cluster_prepared',  3);
    barrier_create('cluster_deployed',  3);
    barrier_create('cluster_test_done', 3);
}

1;

