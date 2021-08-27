# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for 'Enlarge to RAM size'
# checkbox'.
# The checkbox is extracted to the separate package as several pages contain
# it, but different shortcut is used for selecting.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>, Dawei Pang <dawei.pang@suse.com>

package Installation::Partitioner::EnlargeToRAMSizeForSuspendCheckbox;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Element::Checkbox';

use constant {
    CHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX   => 'enabledenlargeswap',
    UNCHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX => 'disabledenlargeswap'
};

sub set_state {
    my ($self, $state) = @_;
    $self->SUPER::set_state(
        state            => $state,
        shortcut         => 'alt-a',
        checked_needle   => CHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX,
        unchecked_needle => UNCHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX
    );
}

1;
