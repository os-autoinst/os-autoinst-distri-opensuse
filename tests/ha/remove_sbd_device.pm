# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Remove a sbd device from cluster
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ha/remove_sbd_device.pm - remove a SBD device from Cluster

=head1 DESCRIPTION

This module is used to remove a second SBD device from Cluster and check the result.

The key tasks performed by this module include:

=over

=item * Waiting dlm init is done.

=item * Get sbd devices

=item * Remove a sbd device from cluster

=item * Check if the device is removed successfully

=back

This includes the lock for multi-machine test.

=over 

=item * C<CLUSTER_DEL_SBD_DEVICE_$cluster_name>

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

    # We need to be sure to be root. After fencing, the default console on node01 is not root.
    if (is_node(1)) {
        reset_consoles;
        select_console 'root-console';
    }

    # Wait for the DLM (Distributed Lock Manager) to finish its initialization.
    # After a fencing test, a newly restarted node has DLM initialization running
    # that result in printing logs to `serial0`.
    # Waiting here prevents output from interfering with subsequent
    # screen assertions and causing false failures.
    my $interval = 10;
    my $timeout = 60;

    while ($timeout > 0) {
        # Run the command to search for the target message in the current boot's journal logs
        my $ret = script_run('journalctl -b --no-pager | grep "mygfs2: join complete"');

        # If the target message is found, exit the loop
        last if ($ret == 0);

        $timeout = $timeout - $interval;
        sleep $interval;
    }

    # get all sbd devices
    my @sbd_conf = parse_sbd_metadata;
    my @sbd_devices = map { $_->{device_name} } @sbd_conf;

    my $remove_dev = shift @sbd_devices;

    if (is_node(1)) {
        assert_script_run("crm sbd device remove $remove_dev");

        # Check the remove result
        if (script_run("crm sbd configure show disk_metadata | grep -F '$remove_dev'")) {
            record_info('SBD remove', "The SBD device $remove_dev is removed");
        }

        # Before remove a sbd device, we have two devices. So there should be one left.
        my $sbd_dev = shift @sbd_devices;
        assert_script_run("crm sbd configure show disk_metadata | grep -F '$sbd_dev'");

        # restart cluster
        script_run('crm cluster restart --all');
        wait_until_resources_started;
    }

    # Wait for one sbd device is removed
    barrier_wait("CLUSTER_DEL_SBD_DEVICE_$cluster_name");

    my @devices = get_sbd_devices($hostname);
    die "Expected 1 devices for $hostname, found " . Dumper(\@devices) unless @devices == 1;
}

1;
