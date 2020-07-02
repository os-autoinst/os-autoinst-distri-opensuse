# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Select Hard Disk(s)
# Page in Guided Setup.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::SelectHardDisksPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';

use constant {
    SELECT_HARD_DISKS_PAGE     => 'select-hard-disks-one-selected',
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
