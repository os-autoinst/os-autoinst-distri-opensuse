# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Add-On Product
# Installation dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::AddOnProductInstallation::AddOnProductInstallationPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{tbl_summary} = $self->{app}->table({id => 'summary'});
    $self->{btn_add} = $self->{app}->button({id => 'add'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_summary}->exist();
}

sub press_add {
    my ($self) = @_;
    return $self->{btn_add}->click();
}

1;
