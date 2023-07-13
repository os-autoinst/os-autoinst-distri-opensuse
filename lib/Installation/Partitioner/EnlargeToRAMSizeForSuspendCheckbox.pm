# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for 'Enlarge to RAM size'
# checkbox'.
# The checkbox is extracted to the separate package as several pages contain
# it, but different shortcut is used for selecting.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>, Dawei Pang <dawei.pang@suse.com>

package Installation::Partitioner::EnlargeToRAMSizeForSuspendCheckbox;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Element::Checkbox';

use constant {
    CHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX => 'enabledenlargeswap',
    UNCHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX => 'disabledenlargeswap'
};

sub set_state {
    my ($self, $state) = @_;
    $self->SUPER::set_state(
        state => $state,
        shortcut => 'alt-a',
        checked_needle => CHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX,
        unchecked_needle => UNCHECKED_ENLARGE_TO_RAM_SIZE_FOR_SUSPEND_CHECKBOX
    );
}

1;
