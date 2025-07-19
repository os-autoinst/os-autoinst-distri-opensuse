# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Add a second SBD device to Cluster
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ha/add_sbd_device.pm - Add a second SBD device to Cluster

=head1 DESCRIPTION

This module is used to add a second SBD device to Cluster and check the result.
For node01: Add SBD device, and check the result.
For node02: After adding is done on node01, check the result.

=cut

use base 'haclusterbasetest';
use strict;
use warnings;
use version_utils qw(is_sle);
use testapi;
use lockapi;
use hacluster;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $cluster_name = get_cluster_name;
    my $lun = get_lun if is_node(1);

    if (is_node(1)) {
        assert_script_run("crm sbd device add $lun");
    }

    # Wait for the second sbd device is added
    barrier_wait("CLUSTER_ADD_SBD_DEVICE_$cluster_name");

    # Check the sbd device
    validate_script_output('crm sbd configure show disk_metadata', qr/$lun/);
}

1;
