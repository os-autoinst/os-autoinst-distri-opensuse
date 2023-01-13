# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Disk Activation page

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::DiskActivationPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{btn_conf_dasd} = $self->{app}->button({id => 'dasd'});
    $self->{btn_conf_zfcp} = $self->{app}->button({id => 'zfcp'});
    $self->{btn_conf_iscsi} = $self->{app}->button({id => 'iscsi'});
    $self->{btn_net_conf} = $self->{app}->button({id => 'network'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_net_conf}->exist();
}

sub press_dasd {
    my ($self) = @_;
    return $self->{btn_conf_dasd}->click();
}

sub press_zfcp {
    my ($self) = @_;
    return $self->{btn_conf_zfcp}->click();
}

sub press_iscsi {
    my ($self) = @_;
    return $self->{btn_conf_iscsi}->click();
}

1;
