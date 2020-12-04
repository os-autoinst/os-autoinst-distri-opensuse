# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods in Expert Partitioner to handle
# a confirmation warning when some devices were modified, but cancel button
# is pressed.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ModifiedDevicesWarning;
use strict;
use warnings;
use parent 'Installation::Partitioner::LibstorageNG::v4_3::ConfirmationWarning';

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{lbl_warning} = $self->{app}->label({label => "You have modified some devices. These changes will be lost\nif you exit the Partitioner.\nReally exit?"});
    return $self;
}

1;
