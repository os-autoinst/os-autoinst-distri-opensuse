# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# Kernel Settings Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::SystemSettings::KernelSettingsTab;
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
    $self->{cb_sysrq} = $self->{app}->checkbox({id => '"sysrq"'});
    return $self;
}

sub uncheck_sysrq {
    my ($self) = @_;
    $self->{cb_sysrq}->uncheck();
}

sub check_sysrq {
    my ($self) = @_;
    $self->{cb_sysrq}->check();
}

1;
