# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Guided Setup of
# Libstorage-NG Partitioner using REST API.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController;

use parent 'Installation::Partitioner::LibstorageNG::GuidedSetupController';
use strict;
use warnings;

use Installation::Partitioner::LibstorageNG::v4_3::SelectDisksToUsePage;

=head1 PARTITION_SETUP

=head2 SYNOPSIS

The class introduces business actions for Guided Setup of Libstorage-NG
Partitioner using REST API.

=cut


sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{SelectDisksToUsePage} = Installation::Partitioner::LibstorageNG::v4_3::SelectDisksToUsePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_select_disks_to_use_page {
    my ($self) = @_;
    die "Disk to use selection page is not displayed" unless $self->{SelectDisksToUsePage}->is_shown();
    return $self->{SelectDisksToUsePage};
}

=head2 guided_setup

 guided_setup($self, %args);

Method setups partitioning using guided setup using provided configuration details.
Following keys can be used:
C<$args{disks}> - Define list of disks to be used (in case of multidisk setup)
C<$args{existing_partitions}> - Process existing partitions, in case those do exist
on the selected disks

=cut

sub guided_setup {
    my ($self, %args) = @_;
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    if (my @disks = @{$args{disks}}) {
        $self->get_select_disks_to_use_page()->select_hard_disks(@disks);
    }
    $self->_set_partitioning(%args);
    $self->get_suggested_partitioning_page()->press_next();
}

1;
