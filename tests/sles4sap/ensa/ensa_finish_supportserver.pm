# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Finish the supportserver configuration
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;

use serial_terminal;
use testapi;
use lockapi qw(barrier_wait);
use hacluster qw(get_cluster_name generate_lun_list);

sub run {
    select_serial_terminal();
    generate_lun_list();
    # Signal to the nodes that are already waiting at the barrier that the supportserver configuration is done.
    my $name = get_cluster_name();
    barrier_wait("BARRIER_HA_$name");
}
1;
