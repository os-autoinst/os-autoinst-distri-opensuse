# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces actions System Settings Dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::SystemSettings::SystemSettingsController;
use strict;
use warnings;
use YaST::SystemSettings::SystemSettingsPage;
use Installation::Partitioner::LibstorageNG::v4_3::ErrorDialog;
use YaST::SystemSettings::PCIIDSetupTab;
use YaST::SystemSettings::AddPCIIDPopup;
use YaST::SystemSettings::KernelSettingsTab;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SystemSettingsPage} = YaST::SystemSettings::SystemSettingsPage->new({app => YuiRestClient::get_app()});
    $self->{ErrorDialog} = Installation::Partitioner::LibstorageNG::v4_3::ErrorDialog->new({app => YuiRestClient::get_app()});
    $self->{KernelSettingsTab} = YaST::SystemSettings::KernelSettingsTab->new({app => YuiRestClient::get_app()});
    $self->{AddPCIIDPopup} = YaST::SystemSettings::AddPCIIDPopup->new({app => YuiRestClient::get_app()});
    $self->{PCIIDSetupTab} = YaST::SystemSettings::PCIIDSetupTab->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_kernel_settings_tab {
    my ($self) = @_;
    return $self->{KernelSettingsTab};
}

sub get_pci_id_setup_tab {
    my ($self) = @_;
    return $self->{PCIIDSetupTab};
}

sub get_add_pci_id_popup {
    my ($self) = @_;
    return $self->{AddPCIIDPopup};
}

sub get_error_dialog {
    my ($self) = @_;
    return $self->{ErrorDialog};
}

sub get_system_settings_page {
    my ($self) = @_;
    return $self->{SystemSettingsPage};
}

sub add_pci_id_from_list {
    my ($self, $args) = @_;
    $self->get_pci_id_setup_tab->press_add_pci_id_from_list();
    $self->get_add_pci_id_popup->set_driver($args->{driver});
    $self->get_add_pci_id_popup->set_sysdir($args->{sysdir});
    $self->get_add_pci_id_popup->press_ok();
    $self->get_system_settings_page->press_ok();
}

sub remove_pci_id {
    my ($self) = @_;
    $self->get_pci_id_setup_tab->press_delete();
    $self->get_system_settings_page->press_ok();
}

sub setup_kernel_settings_sysrq {
    my ($self, $action) = @_;
    $self->get_system_settings_page->switch_tab_kernel();
    $self->set_sysrq_option($action);
    $self->get_system_settings_page->press_ok();
}

sub set_sysrq_option {
    my ($self, $action) = @_;
    if ($action eq "enable") {
        $self->get_kernel_settings_tab->check_sysrq();
    } elsif ($action eq "disable") {
        $self->get_kernel_settings_tab->uncheck_sysrq();
    } else {
        die "Unknown request";
    }
}

1;
