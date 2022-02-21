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
    die "Overview content on Installation Settings Page is not loaded completely" unless $self->{InstallationSettingsPage}->is_loaded_completely();
    return $self->{InstallationSettingsPage};
}

sub wait_for_overview_content_to_be_loaded {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            my $overview_content = $self->get_installation_settings_page()->get_overview_content();
            return ($overview_content =~ m/SSH port will be/);
    }, timeout => 60, message => "Overview content is not loaded.");
}

sub enable_ssh_service {
    my ($self) = @_;
    $self->get_installation_settings_page()->enable_ssh_service();
}

sub open_ssh_port {
    my ($self) = @_;
    $self->get_installation_settings_page()->open_ssh_port();
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
