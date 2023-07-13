# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Add ZFCP Device page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::AddZFCPDeviceController;
use strict;
use warnings;
use Installation::DiskActivation::AddZFCPDevicePage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AddZFCPDevicePage} = Installation::DiskActivation::AddZFCPDevicePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_add_zfcp_device_page {
    my ($self) = @_;
    die "Add ZFCP Device Page is not displayed" unless $self->{AddZFCPDevicePage}->is_shown();
    return $self->{AddZFCPDevicePage};
}

sub configure {
    my ($self, $args) = @_;
    $self->get_add_zfcp_device_page()->set_channel($args->{channel});
    $self->get_add_zfcp_device_page()->press_next();
}

1;
