# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for 'Propose Separate Home
# Partition' checkbox.
# The checkbox is extracted to the separate package as several pages contain
# it, but different shortcut is used for selecting.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::ProposeSeparateHomePartitionCheckbox;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Element::Checkbox';

use constant {
    CHECKED_PROPOSE_SEPARATE_HOME_PARTITION_CHECKBOX   => 'enabledhome',
    UNCHECKED_PROPOSE_SEPARATE_HOME_PARTITION_CHECKBOX => 'disabledhome'
};

sub set_state {
    my ($self, $state) = @_;
    $self->SUPER::set_state(
        state            => $state,
        shortcut         => 'alt-r',
        checked_needle   => CHECKED_PROPOSE_SEPARATE_HOME_PARTITION_CHECKBOX,
        unchecked_needle => UNCHECKED_PROPOSE_SEPARATE_HOME_PARTITION_CHECKBOX
    );
}

1;
