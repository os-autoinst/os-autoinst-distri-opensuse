# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for YaST module
# PCI ID add pop-up window.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
    $self->{btn_ok}    = $self->{app}->button({id => 'ok'});
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
