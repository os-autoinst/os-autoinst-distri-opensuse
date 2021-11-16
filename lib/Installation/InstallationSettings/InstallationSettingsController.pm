# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the Overview Page
#          of the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
    die "Installation Settings Page is not displayed" unless $self->{InstallationSettingsPage}->is_shown();
    return $self->{InstallationSettingsPage};
}

sub enable_ssh_service {
    my ($self) = @_;
    if (!$self->get_installation_settings_page()->is_ssh_enabled()) {
        $self->get_installation_settings_page()->enable_ssh_service();
    }
    if (!$self->get_installation_settings_page()->is_ssh_port_open()) {
        $self->get_installation_settings_page()->open_ssh_port();
    }
    return $self;
}

sub access_booting_options {
    my ($self) = @_;
    $self->get_installation_settings_page()->access_booting_options();
}

sub install {
    my ($self) = @_;
    $self->get_installation_settings_page()->press_install();
}

1;
