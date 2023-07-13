# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Select Hard Disk(s)
# Page in Guided Setup.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::SelectHardDisksPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';

use constant {
    SELECT_HARD_DISKS_PAGE => 'select-hard-disks-one-selected',
    SELECT_HANDLING_PARTITIONS => 'inst-select-disk-to-use-as-root'
};

sub skip_hard_disk_selection {
    my ($self) = @_;
    $self->SUPER::press_next(SELECT_HARD_DISKS_PAGE);
}

sub skip_handling_partitions {
    my ($self) = @_;
    $self->SUPER::press_next(SELECT_HANDLING_PARTITIONS);
}

1;
