# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Guided Setup of
# Libstorage-NG Partitioner.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::GuidedSetupController;
use strict;
use warnings FATAL => 'all';

use Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage;
use Installation::Partitioner::LibstorageNG::PartitioningSchemePage;
use Installation::Partitioner::LibstorageNG::TooSimplePasswordDialog;
use Installation::Partitioner::LibstorageNG::FileSystemOptionsPage;
use Installation::Partitioner::LibstorageNG::SelectHardDisksPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage->new(),
        PartitioningSchemePage    => Installation::Partitioner::LibstorageNG::PartitioningSchemePage->new(),
        TooSimplePasswordDialog   => Installation::Partitioner::LibstorageNG::TooSimplePasswordDialog->new(),
        FileSystemOptionsPage     => Installation::Partitioner::LibstorageNG::FileSystemOptionsPage->new(),
        SelectHardDisksPage       => Installation::Partitioner::LibstorageNG::SelectHardDisksPage->new()
    }, $class;
}

sub get_suggested_partitioning_page {
    my ($self) = @_;
    return $self->{SuggestedPartitioningPage};
}

sub get_partitioning_scheme_page {
    my ($self) = @_;
    return $self->{PartitioningSchemePage};
}

sub get_too_simple_password_dialog {
    my ($self) = @_;
    return $self->{TooSimplePasswordDialog};
}

sub get_file_system_options_page {
    my ($self) = @_;
    return $self->{FileSystemOptionsPage};
}

sub get_select_hard_disks_page {
    my ($self) = @_;
    return $self->{SelectHardDisksPage};
}

sub create_encrypted_partition {
    my ($self, %args) = @_;
    my $is_lvm                = $args{is_lvm};
    my $password              = $args{password};
    my $confirmation_password = $args{confirmation_password};
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    if ($is_lvm) {
        $self->get_partitioning_scheme_page()->enable_logical_volume_management();
    }
    $self->get_partitioning_scheme_page()->select_enable_disk_encryption_checkbox();
    $self->get_partitioning_scheme_page()->enter_password($password);
    $self->get_partitioning_scheme_page()->enter_password_confirmation($confirmation_password);
    $self->get_partitioning_scheme_page()->press_next();
    $self->get_too_simple_password_dialog()->agree_with_too_simple_password();
    $self->get_file_system_options_page()->press_next();
}

sub create_partition {
    my ($self, %args) = @_;
    my $is_lvm = $args{is_lvm};
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    if ($is_lvm) {
        $self->get_partitioning_scheme_page()->enable_logical_volume_management();
    }
    $self->get_partitioning_scheme_page()->press_next();
    $self->get_file_system_options_page()->press_next();
}

sub configure_existing_encrypted_partition {
    my ($self, %args) = @_;
    my $is_lvm                = $args{is_lvm};
    my $password              = $args{password};
    my $confirmation_password = $args{confirmation_password};
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    $self->get_select_hard_disks_page()->press_next();
    $self->create_encrypted_partition(is_lvm => $is_lvm, password => $password, confirmation_password => $confirmation_password);
}

1;
