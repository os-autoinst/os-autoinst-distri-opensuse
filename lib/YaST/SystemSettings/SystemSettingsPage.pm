# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::SystemSettings::SystemSettingsPage;
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
    $self->{btn_ok}  = $self->{app}->button({id => 'next'});
    $self->{tab_cwm} = $self->{app}->tab({id => '_cwm_tab'});
    return $self;
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
    return $self;
}

sub switch_tab_kernel {
    my ($self) = @_;
    $self->{tab_cwm}->select("&Kernel Settings");
    return $self;
}

1;
