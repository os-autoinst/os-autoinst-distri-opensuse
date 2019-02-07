# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Edit Proposal Settings of
# Libstorage Partitioner.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::Libstorage::EditProposalSettingsController;
use strict;
use warnings FATAL => 'all';

use Installation::Partitioner::Libstorage::SuggestedPartitioningPage;
use Installation::Partitioner::Libstorage::ProposalSettingsDialog;
use Installation::Partitioner::Libstorage::PasswordDialog;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        SuggestedPartitioningPage => Installation::Partitioner::Libstorage::SuggestedPartitioningPage->new(),
        ProposalSettingsDialog    => Installation::Partitioner::Libstorage::ProposalSettingsDialog->new(),
        PasswordDialog            => Installation::Partitioner::Libstorage::PasswordDialog->new()
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

sub create_encrypted_partition {
    my ($self, %args) = @_;
    my $password              = $args{password};
    my $confirmation_password = $args{confirmation_password};
    $self->get_suggested_partitioning_page()->press_edit_proposal_settings_button();
    $self->get_proposal_settings_dialog()->select_encrypted_lvm_based_proposal_radiobutton();
    $self->get_password_dialog()->enter_password($password);
    $self->get_password_dialog()->enter_password_confirmation($confirmation_password);
    $self->get_password_dialog()->press_ok();
    $self->get_proposal_settings_dialog()->press_ok();
}

sub create_partition {
    my ($self) = @_;
    $self->get_suggested_partitioning_page()->press_edit_proposal_settings_button();
    $self->get_proposal_settings_dialog()->select_lvm_based_proposal_radiobutton();
    $self->get_proposal_settings_dialog()->press_ok();
}

sub configure_existing_encrypted_partition {
    my ($self) = @_;
    $self->get_suggested_partitioning_page()->press_edit_proposal_settings_button();
    $self->get_proposal_settings_dialog()->select_encrypted_lvm_based_proposal_radiobutton();
    $self->get_proposal_settings_dialog()->press_ok();
}

1;
