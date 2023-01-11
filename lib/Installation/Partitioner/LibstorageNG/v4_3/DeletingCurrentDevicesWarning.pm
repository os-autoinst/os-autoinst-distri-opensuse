# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods in Expert Partitioner to handle
# a confirmation warning when deleting current devices is required.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::DeletingCurrentDevicesWarning;
use strict;
use warnings;
use parent 'Installation::Popups::YesNoPopup';

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{lbl_warning} = $self->{app}->label({label => 'Confirm Deleting of Current Devices'});
    return $self;
}

1;
