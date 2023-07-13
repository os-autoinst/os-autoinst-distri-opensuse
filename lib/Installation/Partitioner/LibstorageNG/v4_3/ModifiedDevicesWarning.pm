# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods in Expert Partitioner to handle
# a confirmation warning when some devices were modified, but cancel button
# is pressed.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::ModifiedDevicesWarning;
use strict;
use warnings;
use parent 'Installation::Popups::YesNoPopup';

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{lbl_warning} = $self->{app}->label({label => "You have modified some devices. These changes will be lost\nif you exit the Partitioner.\nReally exit?"});
    return $self;
}

1;
