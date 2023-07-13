# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the Overview Page
#          of the installer.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::InstallationSettings::InstallationSettingsController;
use strict;
use warnings;
use Installation::InstallationSettings::InstallationSettingsPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{InstallationSettingsPage} = Installation::InstallationSettings::InstallationSettingsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_installation_settings_page {
    my ($self) = @_;
    die "Overview content on Installation Settings Page is not loaded completely" unless $self->{InstallationSettingsPage}->is_loaded_completely();
    return $self->{InstallationSettingsPage};
}

sub open_ssh_port {
    my ($self) = @_;
    $self->get_installation_settings_page()->open_ssh_port();
    $self->get_installation_settings_page()->is_ssh_port_open();
}

sub access_booting_options {
    my ($self) = @_;
    $self->get_installation_settings_page()->access_booting_options();
}

sub access_security_options {
    my ($self) = @_;
    $self->get_installation_settings_page()->access_security_options();
}

sub access_ssh_import_options {
    my ($self) = @_;
    $self->get_installation_settings_page()->access_ssh_import_options();
}

sub install {
    my ($self) = @_;
    $self->get_installation_settings_page()->press_install();
}

sub is_ssh_service_enabled {
    my ($self) = @_;
    $self->get_installation_settings_page()->is_ssh_service_enabled();
}

1;
