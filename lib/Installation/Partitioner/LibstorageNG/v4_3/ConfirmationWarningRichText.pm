# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods in Expert Partitioner to handle
# a generic confirmation warning containing the warning message in YRichText Widget.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ConfirmationWarningRichText;
use strict;
use warnings;
use parent 'Installation::Partitioner::LibstorageNG::v4_3::ConfirmationWarning';

sub init {
    my $self = shift;
    $self->{rt_warning} = $self->{app}->label({type => 'YRichText'});
    return $self;
}

sub text {
    my ($self) = @_;
    return $self->{rt_warning}->text();
}

1;
