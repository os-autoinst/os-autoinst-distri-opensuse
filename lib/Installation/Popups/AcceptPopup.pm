# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to handle
# an Accept license popup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::AcceptPopup;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_accept} = $self->{app}->button({id => 'accept'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{btn_accept}->exist();
}

sub press_accept {
    my ($self) = @_;
    $self->{btn_accept}->click();
}

1;
