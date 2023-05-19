# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents current (i.e. latest) Sle15 distribution and
# provides access to its features.
# Follows the "Factory first" rule. So that the feature first appears in
# Tumbleweed distribution, and only if it behaves different in Sle15 then it
# should be overriden here.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Sle::15_current;
use strict;
use warnings FATAL => 'all';
use parent 'Distribution::Opensuse::Tumbleweed';

use Installation::License::Sle::LicenseAgreementController;
use Installation::License::Sle::Firstboot::LicenseAgreementController;
use Installation::ProductSelection::ProductSelectionController;
use Installation::Registration::RegistrationController;
use Installation::ModuleRegistration::ModuleRegistrationController;
use Installation::ModuleRegistration::ModuleRegistrationInstallationReportController;
use Installation::ModuleSelection::ModuleSelectionController;
use Installation::AddOnProduct::AddOnProductController;
use Installation::RepositoryURL::RepositoryURLController;
use Installation::AddOnProductInstallation::AddOnProductInstallationController;
use Installation::SystemRole::Sle::SystemRoleController;
use Installation::ModuleRegistration::SeparateRegCodesController;
use YaST::DNSServer::Sle::DNSServerController;
use YaST::DNSServer::Sle::DNSServerSetupController;

=head2 get_license_agreement

Returns controller for the EULA page. This page significantly differs
from the openSUSE distributions, therefore has its own controller.

=cut

sub get_license_agreement {
    return Installation::License::Sle::LicenseAgreementController->new();
}

sub get_firstboot_license_agreement {
    return Installation::License::Sle::Firstboot::LicenseAgreementController->new();
}

sub get_product_selection {
    return Installation::ProductSelection::ProductSelectionController->new();
}

sub get_registration {
    return Installation::Registration::RegistrationController->new();
}

sub get_module_registration {
    return Installation::ModuleRegistration::ModuleRegistrationController->new();
}

sub get_module_registration_installation_report {
    return Installation::ModuleRegistration::ModuleRegistrationInstallationReportController->new();
}

sub wait_for_separate_regcode {
    return Installation::ModuleRegistration::SeparateRegCodesController->new();
}

sub get_module_regcode {
    return Installation::ModuleRegistration::SeparateRegCodesController->new();
}

sub get_module_selection {
    return Installation::ModuleSelection::ModuleSelectionController->new();
}

sub get_add_on_product {
    return Installation::AddOnProduct::AddOnProductController->new();
}

sub get_repository_url {
    return Installation::RepositoryURL::RepositoryURLController->new();
}

sub get_add_on_product_installation {
    return Installation::AddOnProductInstallation::AddOnProductInstallationController->new();
}

sub get_system_role_controller() {
    return Installation::SystemRole::Sle::SystemRoleController->new();
}

sub get_dns_server {
    return YaST::DNSServer::Sle::DNSServerController->new();
}

sub get_dns_server_setup {
    return YaST::DNSServer::Sle::DNSServerSetupController->new();
}

1;
