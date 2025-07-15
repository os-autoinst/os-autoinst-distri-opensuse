# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for support server to initialize the barriers
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'haclusterbasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;

sub run {
    my $cluster_name = get_cluster_name;

    diag 'Waiting for barriers creation';
    mutex_wait 'ha_barriers_ready';
    diag "Waiting for barrier $cluster_name...";
    barrier_wait("BARRIER_HA_$cluster_name");
}

1;
