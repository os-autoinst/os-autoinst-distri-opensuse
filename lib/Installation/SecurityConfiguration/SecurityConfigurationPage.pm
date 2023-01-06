# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the
#          Security Configuration page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::SecurityConfiguration::SecurityConfigurationPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{cmb_security_module} = $self->{app}->combobox({id => '"Installation::Widgets::LSMSelector"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_security_module}->exist();
}

sub select_security_module {
    my ($self, $module) = @_;
    return $self->{cmb_security_module}->select($module);
}

1;
