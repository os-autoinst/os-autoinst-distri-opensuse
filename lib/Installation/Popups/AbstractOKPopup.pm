# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The abstract class introduces methods to handle
# an abstract OK popup with unknown content.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::AbstractOKPopup;
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
    $self->{btn_ok} = $self->{app}->button({id => 'ok'});
    return $self;
}

sub is_shown {
    my ($self, $args) = @_;
    return $self->{btn_ok}->exist($args);
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

1;
