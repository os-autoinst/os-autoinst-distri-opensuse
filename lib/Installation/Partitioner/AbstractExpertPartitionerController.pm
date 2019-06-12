# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The abstract class introduces interface to business actions for they
# Expert Partitioner.
# Maintainer: Rodion Iafarov <riafarov@suse.com>

package Installation::Partitioner::AbstractExpertPartitionerController;
use strict;
use warnings;
use testapi;

=head2 add_raid

  add_raid($self, $args);

Create RAID with provided parameters:
$args->{partition}` contains hash reference with parameters for the partiotion,
see C<_add_partition>.
$args->{raid_level} defines wanted raid level.

=cut
sub add_raid();

=head2 accept_changes

  accept_changes($self);

Accept partitioning setup and proceed to the next page.

=cut
sub accept_changes();

=head2 run_expert_partitioner

  run_expert_partitioner($self);

Open Expert Partitioner with existing partitions.

=cut
sub run_expert_partitioner();

=head2 add_partition_on_gpt_disk

  add_partition_on_gpt_disk($self, $args);

Add partition to the disk with gpt partition table.
$args->{disk} contains name of the disk, where partition should be added.
$args->{partition}`contains hash reference with parameters for the partiotion,
see C<_add_partition>.

=cut
sub add_partition_on_gpt_disk();

=head2 _finish_partition_creation

  _finish_partition_creation();

Method finished partitioning, has different implementation in libstorage and
libstorage-ng

=cut
sub _finish_partition_creation();

sub _set_partition_size {
    my ($self, $size) = @_;
    # Check if $size is defined to allow entering '0' size.
    if (defined $size) {
        $self->get_new_partition_size_page()->select_custom_size_radiobutton();
        $self->get_new_partition_size_page()->enter_size($size);
    }
    $self->get_new_partition_size_page()->press_next();
}

sub _set_partition_role {
    my ($self, $role) = @_;
    if ($role) {
        $self->get_role_page()->select_role_radiobutton($role);
    }
    $self->get_role_page()->press_next();
}

sub _set_partition_options {
    my ($self, $args) = @_;
    my $id                 = $args->{id};
    my $formatting_options = $args->{formatting_options};
    my $mounting_options   = $args->{mounting_options};

    # Ste partition id if provided
    if ($id) {
        $self->get_formatting_options_page()->select_partition_id($id);
    }
    # Set Formatting Options:
    if ($formatting_options) {
        if ($formatting_options->{should_format}) {
            $self->get_formatting_options_page()->select_format_device_radiobutton();
            if ($formatting_options->{filesystem}) {
                $self->get_formatting_options_page()->select_filesystem($formatting_options->{filesystem});
            }
        }
        else {
            $self->get_formatting_options_page()->select_do_not_format_device_radiobutton();
        }
    }
    # Set Mounting Options:
    if ($mounting_options) {
        if ($mounting_options->{should_mount}) {
            $self->get_formatting_options_page()->select_mount_device_radiobutton();
            if ($mounting_options->{mount_point}) {
                $self->get_formatting_options_page()->fill_in_mount_point_field($mounting_options->{mount_point});
            }
        }
        else {
            $self->get_formatting_options_page()->select_do_not_mount_device_radiobutton();
        }
    }
}

sub _add_partition {
    my ($self, $args) = @_;

    $self->_set_partition_size($args->{size});
    $self->_set_partition_role($args->{role});
    $self->_set_partition_options($args);
    # This method is different for different versions of storage
    $self->_finish_partition_creation();
}

1;
