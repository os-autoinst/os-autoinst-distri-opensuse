# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for File System Options
# Page when LVM was selected on Partitioning Scheme Page in Guided Setup.
# In this case the elements on the page become different from the common
# File System Options Page, and shortcuts for some similar elements are
# different too.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::FileSystemOptionsLvmPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';
use Installation::Partitioner::ProposeSeparateHomeVolumeCheckbox;

use constant {
    FILE_SYSTEM_OPTIONS_LVM_PAGE => 'inst-filesystem-options'
};

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{propose_separate_home_volume_checkbox} = Installation::Partitioner::ProposeSeparateHomeVolumeCheckbox->new();
    return $self;
}

sub get_propose_separate_home_volume_checkbox {
    my ($self) = @_;
    return $self->{propose_separate_home_volume_checkbox};
}

sub set_state_propose_separate_home_volume_checkbox {
    my ($self, $state) = @_;
    assert_screen(FILE_SYSTEM_OPTIONS_LVM_PAGE);
    $self->get_propose_separate_home_volume_checkbox()->set_state($state);
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(FILE_SYSTEM_OPTIONS_LVM_PAGE);
}

1;
