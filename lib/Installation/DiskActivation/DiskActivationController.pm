# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Disk Activation page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::DiskActivationController;
use strict;
use warnings;
use Installation::DiskActivation::DiskActivationPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{DiskActivationPage} = Installation::DiskActivation::DiskActivationPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_disk_activation_page {
    my ($self) = @_;
    die "Disk Activation Page is not displayed" unless $self->{DiskActivationPage}->is_shown();
    return $self->{DiskActivationPage};
}

sub configure_dasd_disks {
    my ($self) = @_;
    $self->get_disk_activation_page()->press_dasd();
}

sub configure_zfcp_disks {
    my ($self) = @_;
    $self->get_disk_activation_page()->press_zfcp();
}

sub configure_iscsi_disks {
    my ($self) = @_;
    $self->get_disk_activation_page()->press_iscsi();
}

sub accept_disks_configuration {
    my ($self) = @_;
    $self->get_disk_activation_page()->press_next();
}

1;
