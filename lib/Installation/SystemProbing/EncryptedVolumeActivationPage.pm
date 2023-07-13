# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Encrypted Volume Activation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::SystemProbing::EncryptedVolumeActivationPage;
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
    my ($self) = @_;
    $self->{lbl_vol_activation} = $self->{app}->label({label => 'Encrypted Device'});
    $self->{txb_password} = $self->{app}->textbox({id => 'password'});
    $self->{btn_ok} = $self->{app}->button({id => 'accept'});
    $self->{btn_cancel} = $self->{app}->button({id => 'cancel'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_vol_activation}->exist();
}

sub enter_password {
    my ($self, $encryption_password) = @_;
    return $self->{txb_password}->set($encryption_password);
}

sub press_ok {
    my ($self) = @_;
    return $self->{btn_ok}->click();
}

sub press_cancel {
    my ($self) = @_;
    return $self->{btn_cancel}->click();
}

1;
