# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Change SBD metadata and check result
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ha/change_sbd_metadata.pm - Change SBD metadata value.

=head1 DESCRIPTION

This module is used to check if metadata could be changed as expected, e.g. watchdog-timeout,
allocate-timeout, msgwait-timeout, loop-timeout

The key tasks performed by this module include:

=over

=item * Get the metadata configuration

=item * Set each xxxx-timeout to $default_value + 2 on node01

=item * Check if the changes affect on node01 and node02

=item * Recover the metadata

=back

This includes the lock for multi-machine test.

=over 

=item * C<CLUSTER_BEFORE_CHANGE_METADATA_$cluster_name>

=item * C<CLUSTER_AFTER_CHANGE_METADATA_$cluster_name>

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

sub run {
    my $cluster_name = get_cluster_name;

    my $change_num = 2;

    my @sbd_conf = parse_sbd_metadata();
    my $metadata_config = $sbd_conf[0]->{metadata};

    # Need to get the orignial values before changing metadata, so barrier_wait is needed here.
    barrier_wait("CLUSTER_BEFORE_CHANGE_METADATA_$cluster_name");


    # Configure the metadata
    assert_script_run("crm sbd configure " . join(" ", map { "$_-timeout=" . ($metadata_config->{$_} + $change_num) } keys %$metadata_config)) if (is_node(1));

    barrier_wait("CLUSTER_AFTER_CHANGE_METADATA_$cluster_name");

    # Check metadata
    my @new_sbd_conf = parse_sbd_metadata();
    my $new_metadata_config = $new_sbd_conf[0]->{metadata};
    foreach my $key (keys %$new_metadata_config) {
        my $expected_val = $metadata_config->{$key} + $change_num;
        die "The metadata $key is not changed as expected" if ($new_metadata_config->{$key} ne $expected_val);
    }

    barrier_wait("CLUSTER_CHECK_CHANGE_METADATA_$cluster_name");

    # Recover metadata configuration
    assert_script_run("crm sbd configure " . join(" ", map { "$_-timeout=" . $metadata_config->{$_} } keys %$metadata_config)) if (is_node(1));
}

1;
