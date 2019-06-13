# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Expert Partitioner
# Page.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

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
