# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class represents Tumbleweed distribution and provides access to
# its features.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Distribution::Opensuse::Tumbleweed;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';
use Installation::AuthenticationForRoot::AuthenticationForRootController;
use Installation::ClockAndTimeZone::ClockAndTimeZoneController;
use Installation::License::Opensuse::Firstboot::LicenseAgreementController;
use Installation::License::LicenseAgreementCustomController;
use Installation::LocalUser::LocalUserController;
use Installation::Overview::OverviewController;
use Installation::Registration::RegisteredSystemController;
use Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController;
use Installation::SystemRole::SystemRoleController;
use YaST::Bootloader::BootloaderController;
use YaST::Firstboot::ConfigurationCompletedController;
use YaST::Firstboot::HostNameController;
use YaST::Firstboot::LanguageAndKeyboardLayoutController;
use YaST::Firstboot::KeyboardLayoutController;
use YaST::Firstboot::NTPConfigurationController;
use YaST::Firstboot::WelcomeController;
use YaST::NetworkSettings::v4_3::NetworkSettingsController;
use YaST::SystemSettings::SystemSettingsController;

sub get_partitioner {
    return Installation::Partitioner::LibstorageNG::GuidedSetupController->new();
}

sub get_guided_partitioner {
    return Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController->new();
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

sub get_overview_controller {
    return Installation::Overview::OverviewController->new();
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

sub get_bootloader {
    return YaST::Bootloader::BootloaderController->new();
}

1;
