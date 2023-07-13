# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Guided Setup of
# Libstorage-NG Partitioner.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::GuidedSetupController;
use strict;
use warnings FATAL => 'all';

use Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage;
use Installation::Partitioner::LibstorageNG::PartitioningSchemePage;
use Installation::Partitioner::LibstorageNG::TooSimplePasswordDialog;
use Installation::Partitioner::LibstorageNG::FileSystemOptionsPage;
use Installation::Partitioner::LibstorageNG::FileSystemOptionsLvmPage;
use Installation::Partitioner::LibstorageNG::SelectHardDisksPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage->new(),
        PartitioningSchemePage => Installation::Partitioner::LibstorageNG::PartitioningSchemePage->new(),
        TooSimplePasswordDialog => Installation::Partitioner::LibstorageNG::TooSimplePasswordDialog->new(),
        FileSystemOptionsPage => Installation::Partitioner::LibstorageNG::FileSystemOptionsPage->new(),
        FileSystemOptionsLvmPage => Installation::Partitioner::LibstorageNG::FileSystemOptionsLvmPage->new(),
        SelectHardDisksPage => Installation::Partitioner::LibstorageNG::SelectHardDisksPage->new()
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

sub get_file_system_options_lvm_page {
    my ($self) = @_;
    return $self->{FileSystemOptionsLvmPage};
}

sub get_select_hard_disks_page {
    my ($self) = @_;
    return $self->{SelectHardDisksPage};
}

sub edit_proposal {
    my ($self, %args) = @_;
    my $multiple_disks = $args{multiple_disks};

    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    $self->get_select_hard_disks_page()->skip_hard_disk_selection() if $multiple_disks;
    $self->_set_partitioning(%args);
}

sub edit_proposal_for_existing_partition {
    my ($self, %args) = @_;
    $self->get_suggested_partitioning_page()->press_guided_setup_button();
    $self->get_select_hard_disks_page()->skip_handling_partitions();
    $self->_set_partitioning(%args);
}

# The method proceeds through the Guided Setup Wizard and sets the data, that
# is specified by the method parameters.
# This allows a test to select the specified options, depending on the data that
# it provides to the method, instead of making different set of methods for all
# the required test combinations.
sub _set_partitioning {
    my ($self, %args) = @_;
    my $is_lvm = $args{is_lvm};
    my $is_encrypted = $args{is_encrypted};
    my $has_separate_home = $args{has_separate_home};
    my $has_enlarge_swap = $args{has_enlarge_swap};
    if ($is_lvm) {
        $self->get_partitioning_scheme_page()->select_logical_volume_management_checkbox();
    }
    if ($is_encrypted) {
        $self->_encrypt_with_too_simple_password();
    }
    else {
        $self->get_partitioning_scheme_page()->press_next();
    }
    if (defined $has_separate_home) {
        if ($is_lvm) {
            $self->get_file_system_options_lvm_page()->set_state_propose_separate_home_volume_checkbox($has_separate_home);
        }
        else {
            $self->get_file_system_options_page()->set_state_propose_separate_home_partition_checkbox($has_separate_home);
        }
    }
    if (defined $has_enlarge_swap) {
        $self->get_file_system_options_page()->set_state_enlarge_to_ram_size_for_suspend_checkbox($has_enlarge_swap);
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
    $self->get_too_simple_password_dialog()->press_yes();
}

1;
