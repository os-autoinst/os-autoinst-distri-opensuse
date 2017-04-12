# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize barriers used in CaaSP cluster tests
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use lockapi;
use mmapi;

sub run() {
    # Number of parallel jobs
    my $jobs = 4;

    barrier_create("VELUM_STARTED",     $jobs);        # Velum node is ready
    barrier_create("WORKERS_INSTALLED", $jobs - 1);    # Nodes are installed
    barrier_create("CNTRL_FINISHED",    $jobs);        # We are finished with testing
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
