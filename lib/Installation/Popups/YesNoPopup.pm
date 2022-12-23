# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to handle a generic yes/no
# popup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::YesNoPopup;
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
    $self->{btn_yes} = $self->{app}->button({id => 'yes'});
    $self->{btn_no} = $self->{app}->button({id => qr/^(no|no_button)$/});
    $self->{lbl_warning} = $self->{app}->label({type => 'YLabel'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_yes}->exist();
}

sub press_yes {
    my ($self) = @_;
    return $self->{btn_yes}->click();
}

sub press_no {
    my ($self) = @_;
    return $self->{btn_no}->click();
}

sub text {
    my ($self) = @_;
    return $self->{lbl_warning}->text();
}

1;
