# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Edit Proposal Settings of
# Libstorage Partitioner.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::Libstorage::EditProposalSettingsController;
use strict;
use warnings FATAL => 'all';
use testapi;

use Installation::Partitioner::Libstorage::SuggestedPartitioningPage;
use Installation::Partitioner::Libstorage::ProposalSettingsDialog;
use Installation::Partitioner::Libstorage::PasswordDialog;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::Libstorage::SuggestedPartitioningPage->new(),
        ProposalSettingsDialog => Installation::Partitioner::Libstorage::ProposalSettingsDialog->new(),
        PasswordDialog => Installation::Partitioner::Libstorage::PasswordDialog->new()
    }, $class;
}

sub get_suggested_partitioning_page {
    my ($self) = @_;
    return $self->{SuggestedPartitioningPage};
}

sub get_proposal_settings_dialog {
    my ($self) = @_;
    return $self->{ProposalSettingsDialog};
}

sub get_password_dialog {
    my ($self) = @_;
    return $self->{PasswordDialog};
}

sub edit_proposal {
    my ($self, %args) = @_;
    $self->get_suggested_partitioning_page()->press_edit_proposal_settings_button();
    $self->_set_partitioning(%args);
}

sub edit_proposal_for_existing_partition {
    my ($self, %args) = @_;
    $self->edit_proposal(%args);
}

# The method allows to select the required options in Proposed Settings Dialog
# using method parameters.
# This allows test to select the specified options, depending on the data that
# it provides to the method, instead of making different set of methods for all
# the required test combinations.
sub _set_partitioning {
    my ($self, %args) = @_;
    my $is_lvm = $args{is_lvm};
    my $is_encrypted = $args{is_encrypted};
    my $has_separate_home = $args{has_separate_home};
    if ($is_lvm) {
        if ($is_encrypted) {
            $self->_encrypt_with_lvm();
        }
        else {
            $self->get_proposal_settings_dialog()->select_lvm_based_proposal_radiobutton();
        }
    }
    if (defined $has_separate_home) {
        $self->get_proposal_settings_dialog()->set_state_separate_home_partition_checkbox($has_separate_home);
    }
    $self->get_proposal_settings_dialog()->press_ok();
}

sub _encrypt_with_lvm {
    my ($self) = @_;
    $self->get_proposal_settings_dialog()->select_encrypted_lvm_based_proposal_radiobutton();
    if (get_var('ENCRYPT_FORCE_RECOMPUTE')) {
        record_soft_failure('bsc#1108790');
        return;
    }
    $self->get_password_dialog()->enter_password();
    $self->get_password_dialog()->enter_password_confirmation();
    $self->get_password_dialog()->press_ok();

}

1;
