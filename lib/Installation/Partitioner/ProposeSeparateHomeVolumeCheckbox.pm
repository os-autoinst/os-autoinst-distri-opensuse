# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for 'Propose Separate Home
# Volume' checkbox.
# The checkbox is extracted to the separate package as several pages contain
# it, but different shortcut is used for selecting.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::ProposeSeparateHomeVolumeCheckbox;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Element::Checkbox';

use constant {
    CHECKED_PROPOSE_SEPARATE_HOME_VOLUME_CHECKBOX => 'enabledhome',
    UNCHECKED_PROPOSE_SEPARATE_HOME_VOLUME_CHECKBOX => 'disabledhome'
};

sub set_state {
    my ($self, $state) = @_;
    $self->SUPER::set_state(
        state => $state,
        shortcut => 'alt-p',
        checked_needle => CHECKED_PROPOSE_SEPARATE_HOME_VOLUME_CHECKBOX,
        unchecked_needle => UNCHECKED_PROPOSE_SEPARATE_HOME_VOLUME_CHECKBOX
    );
}

1;
