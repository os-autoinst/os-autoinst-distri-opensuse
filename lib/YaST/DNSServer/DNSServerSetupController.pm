# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces actions for DNS Server Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::DNSServer::DNSServerSetupController;
use strict;
use warnings;
use YaST::DNSServer::ForwarderSettingsPage;
use YaST::DNSServer::ZonesPage;
use YaST::DNSServer::FinishWizardPage;
use Installation::Popups::YesNoPopup;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{FWSettingsPage} = YaST::DNSServer::ForwarderSettingsPage->new({app => YuiRestClient::get_app()});
    $self->{ZonesPage} = YaST::DNSServer::ZonesPage->new({app => YuiRestClient::get_app()});
    $self->{FinishWizardPage} = YaST::DNSServer::FinishWizardPage->new({app => YuiRestClient::get_app()});
    $self->{WeakPasswordPopup} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub process_reading_configuration {
    my ($self) = @_;
    $self->continue_with_interfaces_controlled_by_nm();
    return $self->get_forwarder_settings_page();
}

sub get_forwarder_settings_page {
    my ($self) = @_;
    die 'ForwarderSetting Page is not displayed' unless $self->{FWSettingsPage}->is_shown();
    return $self->{FWSettingsPage};
}

sub get_zones_page {
    my ($self) = @_;
    die 'Zones Pane is not displayed' unless $self->{ZonesPage}->is_shown();
    return $self->{ZonesPage};
}

sub get_finish_wizard_page {
    my ($self) = @_;
    die 'Finish wizard page is not displayed' unless $self->{FinishWizardPage}->is_shown();
    return $self->{FinishWizardPage};
}

sub get_weak_password_warning {
    my ($self) = @_;
    die "Popup for too simple password is not displayed" unless $self->{WeakPasswordPopup}->is_shown();
    return $self->{WeakPasswordPopup};
}

sub get_network_manager_warning_page {
    my ($self) = @_;
    die 'Network Manager Warning page is not displayed' unless $self->{networkpage}->is_shown();
    return $self->{networkpage};
}

sub continue_with_interfaces_controlled_by_nm {
    my ($self) = @_;
    $self->get_weak_password_warning()->press_yes();
}

sub accept_forwarder_settings {
    my ($self) = @_;
    $self->get_forwarder_settings_page()->press_next();
}

sub accept_dns_zones {
    my ($self) = @_;
    $self->get_zones_page()->press_next();
}

sub finish_setup {
    my ($self) = @_;
    $self->get_finish_wizard_page()->press_next();
}

sub select_start_after_writing_configuration {
    my ($self) = @_;
    $self->get_finish_wizard_page()->set_action('Start');
}

sub select_start_on_boot_after_reboot {
    my ($self) = @_;
    $self->get_finish_wizard_page()->set_autostart('Start on boot');
}

1;
