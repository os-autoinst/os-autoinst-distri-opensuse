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

sub edit_proposal {
    my ($self, %args) = @_;
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    $self->_set_partitioning(%args);
}

sub edit_proposal_for_existing_partition {
    my ($self, %args) = @_;
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    $self->get_select_hard_disks_page()->press_next();
    $self->_set_partitioning(%args);
}

# The method proceeds through the Guided Setup Wizard and sets the data, that
# is specified by the method parameters.
# This allows a test to select the specified options, depending on the data that
# it provides to the method, instead of making different set of methods for all
# the required test combinations.
sub _set_partitioning {
    my ($self, %args) = @_;
    my $is_lvm       = $args{is_lvm};
    my $is_encrypted = $args{is_encrypted};
    if ($is_lvm) {
        $self->get_partitioning_scheme_page()->select_logical_volume_management_checkbox();
    }
    if ($is_encrypted) {
        $self->_encrypt_with_too_simple_password();
    }
    else {
        $self->get_partitioning_scheme_page()->press_next();
    }
    $self->get_file_system_options_page()->press_next();
}

# The default password which is used in the tests is determined as "too simple"
# by the Libstorage-NG. This forces test to close the "too simple" popup each
# time.
# Random strong password would be preferable here, but due to current tests
# infrastructure there is no simple solution to propogate random strong password
# to another tests that require the password.
sub _encrypt_with_too_simple_password {
    my ($self) = @_;
    $self->get_partitioning_scheme_page()->select_enable_disk_encryption_checkbox();
    $self->get_partitioning_scheme_page()->enter_password();
    $self->get_partitioning_scheme_page()->enter_password_confirmation();
    $self->get_partitioning_scheme_page()->press_next();
    $self->get_too_simple_password_dialog()->press_ok();
}

1;
