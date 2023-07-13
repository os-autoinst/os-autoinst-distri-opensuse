# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to handle an OK/Stop
# popup containing the message in YRichText Widget.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::OKStopPopup;
use strict;
use warnings;
use parent 'Installation::Popups::OKPopup';

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{lbl_counter} = $self->{app}->label({id => '__timeout_label'});
    $self->{btn_stop} = $self->{app}->button({id => '__stop'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_stop}->exist();
}

sub press_stop {
    my ($self) = @_;
    $self->{btn_stop}->click();
}

1;
