# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Expert Partitioner
# Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::ExpertPartitionerPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::ExpertPartitionerPage';

use constant {
    ADD_RAID_PARTITION_ITEM_IN_DROPDOWN => 'add-partition'
};

sub select_add_partition_for_raid {
    my ($self) = @_;
    assert_screen($self->EXPERT_PARTITIONER_PAGE);
    send_key('alt-p');    # Partitions drop-down menu
    assert_and_click(ADD_RAID_PARTITION_ITEM_IN_DROPDOWN);
}

1;
