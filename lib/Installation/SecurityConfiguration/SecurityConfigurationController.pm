# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the
#          Security Configuration page in the installer.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::SecurityConfiguration::SecurityConfigurationController;
use strict;
use warnings;
use Installation::SecurityConfiguration::SecurityConfigurationPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SecurityConfigurationPage} = Installation::SecurityConfiguration::SecurityConfigurationPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_security_configuration_page {
    my ($self) = @_;
    die "Security Configuration page is not displayed" unless $self->{SecurityConfigurationPage}->is_shown();
    return $self->{SecurityConfigurationPage};
}

sub select_security_module {
    my ($self, $module) = @_;
    $self->get_security_configuration_page()->select_security_module($module);
    $self->get_security_configuration_page()->press_next();
}

1;
