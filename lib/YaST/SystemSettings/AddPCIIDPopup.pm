# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# PCI ID add pop-up window.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::SystemSettings::AddPCIIDPopup;
use strict;
use warnings;
use testapi;

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
    $self->{tb_driver} = $self->{app}->textbox({id => 'driver'});
    $self->{tb_sysdir} = $self->{app}->textbox({id => 'sysdir'});
    return $self;
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
    return $self;
}

sub set_driver {
    my ($self, $driver) = @_;
    $self->{tb_driver}->set($driver);
}

sub set_sysdir {
    my ($self, $sysdir) = @_;
    $self->{tb_sysdir}->set($sysdir);
}

1;
