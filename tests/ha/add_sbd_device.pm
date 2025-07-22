# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Add a SBD device to Cluster
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ha/add_sbd_device.pm - Add a second SBD device to Cluster

=head1 DESCRIPTION

This module is used to add a second SBD device to a cluster and check the result.

The key tasks performed by this module include:

=over

=item * Add a SBD device on node01

=item * Restart cluster to apply the change

=item * Check `crm sbd status` result on node01 and node02, there should be two sbd devices.

=back

This includes the lock for multi-machine test.

=over 

=item * C<CLUSTER_ADD_SBD_DEVICE_$cluster_name>

=back

=head1 VARIABLES

This list only cites variables explicitly used in this module.

=over

=item B<HOSTNAME>

The hostname of current node.

=back

=cut

use base 'haclusterbasetest';
use testapi;
use lockapi;
use hacluster;
use Data::Dumper;

sub run {
    my $cluster_name = get_cluster_name;
    my $hostname = get_var('HOSTNAME');
    my $lun = get_lun;

    if (is_node(1)) {
        assert_script_run("crm sbd device add $lun");

        # Check the sbd device is added into the configuration
        validate_script_output('crm sbd configure show disk_metadata', qr/$lun/);

        # restart cluster
        script_run('crm cluster restart --all');
        wait_until_resources_started;
    }

    # Wait for the second sbd device is added
    barrier_wait("CLUSTER_ADD_SBD_DEVICE_$cluster_name");

    # Get sbd devices
    my @devices = get_sbd_devices($hostname);
    die "Expected 2 devices for $hostname, found " . Dumper(\@devices) unless @devices == 2;

    if (is_node(1)) {
        my $found = grep { $_ eq $lun } @devices;
        die "New device $lun not found in watcher list" unless $found;
    }
}

1;
