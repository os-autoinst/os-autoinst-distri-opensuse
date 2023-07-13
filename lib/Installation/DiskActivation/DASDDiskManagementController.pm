# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces business actions for DASD Disk Management page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::DASDDiskManagementController;
use strict;
use warnings;
use Installation::DiskActivation::DASDDiskManagementPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{DASDDiskManagementPage} = Installation::DiskActivation::DASDDiskManagementPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_dasd_disk_management_page {
    my ($self) = @_;
    die "DASD Disk Management page is not displayed" unless $self->{DASDDiskManagementPage}->is_shown();
    return $self->{DASDDiskManagementPage};
}

sub filter_channel {
    my ($self, $channel) = @_;
    $self->get_dasd_disk_management_page()->enter_minimum_channel($channel);
    $self->get_dasd_disk_management_page()->enter_maximum_channel($channel);
    $self->get_dasd_disk_management_page()->press_filter_button();
}

sub activate_device {
    my ($self, $channel) = @_;
    $self->get_dasd_disk_management_page()->select_device($channel);
    $self->get_dasd_disk_management_page()->perform_action_activate();
}

sub accept_configuration {
    my ($self) = @_;
    $self->get_dasd_disk_management_page()->press_next();
}

1;
