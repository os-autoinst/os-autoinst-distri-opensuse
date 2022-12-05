# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents Tumbleweed distribution and provides access to
# its features.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Distribution::Opensuse::Tumbleweed;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';
use Installation::AuthenticationForRoot::AuthenticationForRootController;
use Installation::ClockAndTimeZone::ClockAndTimeZoneController;
use Installation::DiskActivation::DiskActivationController;
use Installation::DiskActivation::ConfiguredZFCPDevicesController;
use Installation::DiskActivation::AddZFCPDeviceController;
use Installation::DiskActivation::DASDDiskManagementController;
use Installation::LanguageKeyboard::LanguageKeyboardController;
use Installation::License::Opensuse::Firstboot::LicenseAgreementController;
use Installation::License::Opensuse::LicenseAgreementController;
use Installation::License::LicenseAgreementCustomController;
use Installation::LocalUser::LocalUserController;
use Installation::Navigation::NavigationController;
use Installation::InstallationSettings::InstallationSettingsController;
use Installation::Registration::RegisteredSystemController;
use Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::FilesystemOptionsController;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::PartitioningSchemeController;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::SelectHardDisksController;
use Installation::Partitioner::LibstorageNG::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController;
use Installation::PerformingInstallation::PerformingInstallationController;
use Installation::SecurityConfiguration::SecurityConfigurationController;
use Installation::SSHKeyImport::SSHKeyImportController;
use Installation::SystemProbing::EncryptedVolumeActivationController;
use Installation::SystemRole::SystemRoleController;
use Installation::Popups::OKPopupController;
use Installation::Popups::YesNoPopupController;
use YaST::Bootloader::BootloaderSettingsController;
use YaST::Firstboot::ConfigurationCompletedController;
use YaST::Firstboot::HostNameController;
use YaST::Firstboot::LanguageAndKeyboardLayoutController;
use YaST::Firstboot::KeyboardLayoutController;
use YaST::Firstboot::NTPConfigurationController;
use YaST::Firstboot::WelcomeController;
use YaST::NetworkSettings::v4_3::NetworkSettingsController;
use YaST::SystemSettings::SystemSettingsController;
use YaST::Firewall::FirewallController;
use YaST::DNSServer::DNSServerController;
use YaST::DNSServer::DNSServerSetupController;

sub get_language_keyboard {
    return Installation::LanguageKeyboard::LanguageKeyboardController->new();
}

sub get_partitioner {
    return Installation::Partitioner::LibstorageNG::GuidedSetupController->new();
}

sub get_guided_partitioner {
    return Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController->new();
}

sub get_select_hard_disks {
    return Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::SelectHardDisksController->new();
}

sub get_partitioning_scheme {
    return Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::PartitioningSchemeController->new();
}

sub get_filesystem_options {
    return Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::FilesystemOptionsController->new();
}

sub get_expert_partitioner {
    return Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController->new();
}

sub get_firstboot_configuration_completed {
    return YaST::Firstboot::ConfigurationCompletedController->new();
}

sub get_firstboot_host_name {
    return YaST::Firstboot::HostNameController->new();
}

sub get_firstboot_keyboard_layout {
    return YaST::Firstboot::KeyboardLayoutController->new();
}

sub get_firstboot_language_and_keyboard_layout {
    return YaST::Firstboot::LanguageAndKeyboardLayoutController->new();
}

sub get_firstboot_license_agreement {
    return Installation::License::Opensuse::Firstboot::LicenseAgreementController->new();
}

sub get_firstboot_license_agreement_custom {
    return Installation::License::LicenseAgreementCustomController->new();
}

sub get_firstboot_ntp_configuration {
    return YaST::Firstboot::NTPConfigurationController->new();
}

sub get_firstboot_welcome {
    return YaST::Firstboot::WelcomeController->new();
}

sub get_firewall {
    return YaST::Firewall::FirewallController->new();
}

sub get_navigation {
    return Installation::Navigation::NavigationController->new();
}

sub get_installation_settings {
    return Installation::InstallationSettings::InstallationSettingsController->new();
}

sub get_network_settings {
    return YaST::NetworkSettings::v4_3::NetworkSettingsController->new();
}

sub get_system_role_controller() {
    return Installation::SystemRole::SystemRoleController->new();
}

sub get_system_settings {
    return YaST::SystemSettings::SystemSettingsController->new();
}

sub get_suggested_partitioning() {
    return Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController->new();
}

sub get_clock_and_time_zone {
    return Installation::ClockAndTimeZone::ClockAndTimeZoneController->new();
}

sub get_local_user {
    return Installation::LocalUser::LocalUserController->new();
}

sub get_authentication_for_root {
    return Installation::AuthenticationForRoot::AuthenticationForRootController->new();
}

sub get_registration_of_registered_system {
    return Installation::Registration::RegisteredSystemController->new();
}

sub get_bootloader_settings {
    return YaST::Bootloader::BootloaderSettingsController->new();
}

sub get_license_agreement {
    return Installation::License::Opensuse::LicenseAgreementController->new();
}

sub get_ok_popup_controller {
    return Installation::Popups::OKPopupController->new();
}

sub get_yes_no_popup_controller {
    return Installation::Popups::YesNoPopupController->new();
}

sub get_encrypted_volume_activation {
    return Installation::SystemProbing::EncryptedVolumeActivationController->new();
}

sub get_disk_activation {
    return Installation::DiskActivation::DiskActivationController->new();
}

sub get_configured_zfcp_devices {
    return Installation::DiskActivation::ConfiguredZFCPDevicesController->new();
}

sub get_add_new_zfcp_device {
    return Installation::DiskActivation::AddZFCPDeviceController->new();
}

sub get_dasd_disk_management {
    return Installation::DiskActivation::DASDDiskManagementController->new();
}

sub get_performing_installation {
    return Installation::PerformingInstallation::PerformingInstallationController->new();
}

sub get_ssh_import_settings {
    return Installation::SSHKeyImport::SSHKeyImportController->new();
}

sub get_security_configuration {
    return Installation::SecurityConfiguration::SecurityConfigurationController->new();
}

sub get_dns_server {
    return YaST::DNSServer::DNSServerController->new();
}

sub get_dns_server_setup {
    return YaST::DNSServer::DNSServerSetupController->new();
}

1;
