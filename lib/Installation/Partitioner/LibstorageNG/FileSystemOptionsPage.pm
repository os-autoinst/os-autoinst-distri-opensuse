# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for File System Options
# Page in Guided Setup.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::FileSystemOptionsPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';
use Installation::Partitioner::ProposeSeparateHomePartitionCheckbox;
use Installation::Partitioner::EnlargeToRAMSizeForSuspendCheckbox;

use constant {
    FILE_SYSTEM_OPTIONS_PAGE => 'inst-filesystem-options'
};

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{propose_separate_home_partition_checkbox} = Installation::Partitioner::ProposeSeparateHomePartitionCheckbox->new();
    $self->{enlarge_to_ram_size_for_suspend_checkbox} = Installation::Partitioner::EnlargeToRAMSizeForSuspendCheckbox->new();
    return $self;
}

sub get_propose_separate_home_partition_checkbox {
    my ($self) = @_;
    return $self->{propose_separate_home_partition_checkbox};
}

sub set_state_propose_separate_home_partition_checkbox {
    my ($self, $state) = @_;
    assert_screen(FILE_SYSTEM_OPTIONS_PAGE);
    $self->get_propose_separate_home_partition_checkbox()->set_state($state);
}


sub get_enlarge_to_ram_size_for_suspend_checkbox {
    my ($self) = @_;
    return $self->{enlarge_to_ram_size_for_suspend_checkbox};
}


sub set_state_enlarge_to_ram_size_for_suspend_checkbox {
    my ($self, $state) = @_;
    assert_screen(FILE_SYSTEM_OPTIONS_PAGE);
    $self->get_enlarge_to_ram_size_for_suspend_checkbox()->set_state($state);
}


sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(FILE_SYSTEM_OPTIONS_PAGE);
}

1;
