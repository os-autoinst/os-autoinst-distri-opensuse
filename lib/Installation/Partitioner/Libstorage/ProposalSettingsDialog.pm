# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Proposal Settings
# Dialog that appears after pressing an appropriate button on Suggested
# Partitioning Page.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::Libstorage::ProposalSettingsDialog;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';
use Installation::Partitioner::ProposeSeparateHomePartitionCheckbox;

use constant {
    PROPOSAL_SETTINGS_DIALOG => 'inst-partition-radio-buttons'
};

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{separate_home_partition_checkbox} = Installation::Partitioner::ProposeSeparateHomePartitionCheckbox->new();
    return $self;
}

sub get_separate_home_partition_checkbox {
    my ($self) = @_;
    return $self->{separate_home_partition_checkbox};
}

sub select_encrypted_lvm_based_proposal_radiobutton {
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    send_key('alt-e');
}

sub select_lvm_based_proposal_radiobutton {
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    send_key('alt-l');
}

sub press_ok {
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    send_key('alt-o');
}

sub set_state_separate_home_partition_checkbox {
    my ($self, $has_separate_home) = @_;
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    $self->get_separate_home_partition_checkbox()->set_state($has_separate_home);
}

1;
