# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods in Expert Partitioner to handle
# an OK popup containing the message in YRichText Widget.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::OKPopup;
use strict;
use warnings;
use parent 'Installation::Popups::AbstractOKPopup';

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{rct_warning} = $self->{app}->richtext({type => 'YRichText'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->SUPER::is_shown() &&
      $self->{rct_warning}->exist();
}

sub text {
    my ($self) = @_;
    return $self->{rct_warning}->text();
}

1;
