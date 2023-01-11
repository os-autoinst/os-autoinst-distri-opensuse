# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Configure ZFCP devices page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::ConfiguredZFCPDevicesController;
use strict;
use warnings;
use Installation::DiskActivation::ConfiguredZFCPDevicesPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ZFCPConfigurationPage} = Installation::DiskActivation::ConfiguredZFCPDevicesPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_zfcp_configuration_page {
    my ($self) = @_;
    die "Configured ZFCP devices page is not displayed" unless $self->{ZFCPConfigurationPage}->is_shown();
    return $self->{ZFCPConfigurationPage};
}

sub get_devices {
    my ($self) = @_;
    return $self->get_zfcp_configuration_page()->get_devices();
}

sub add {
    my ($self) = @_;
    $self->get_zfcp_configuration_page()->press_add();
}

sub accept_devices {
    my ($self) = @_;
    $self->get_zfcp_configuration_page()->press_next();
}


1;
