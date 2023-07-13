# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with page that give module registration installation report
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ModuleRegistration::ModuleRegistrationInstallationReportPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{btn_finish} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_finish}->exist();
}

1;
