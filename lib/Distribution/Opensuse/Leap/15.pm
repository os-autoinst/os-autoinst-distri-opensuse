# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents current (i.e. latest) Leap 15 distribution and
# provides access to its features.
# It follows latest SLE 15 and only if it behaves different in Leap 15 then it
# should be overriden here.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Distribution::Opensuse::Leap::15;
use strict;
use warnings FATAL => 'all';
use parent 'Distribution::Sle::15_current';
use Installation::License::Opensuse::Firstboot::LicenseAgreementController;
use Installation::License::Opensuse::LicenseAgreementController;
use Installation::SystemRole::SystemRoleController;

=head2 get_firstboot_license_agreement

Returns controller for license agreement which differs from SLE due to
openSUSE use a different UI flow to accept the default license.

=cut

sub get_firstboot_license_agreement {
    return Installation::License::Opensuse::Firstboot::LicenseAgreementController->new();
}

sub get_license_agreement {
    return Installation::License::Opensuse::LicenseAgreementController->new();
}

sub get_system_role_controller {
    return Installation::SystemRole::SystemRoleController->new();
}

1;
