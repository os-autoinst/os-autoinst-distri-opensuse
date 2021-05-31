# SUSE's openQA tests
#
# Copyright © 2019-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class represents current (i.e. latest) Sle15 distribution and
# provides access to its features.
# Follows the "Factory first" rule. So that the feature first appears in
# Tumbleweed distribution, and only if it behaves different in Sle15 then it
# should be overriden here.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Distribution::Sle::15_current;
use strict;
use warnings FATAL => 'all';
use parent 'Distribution::Opensuse::Tumbleweed';

use Installation::License::Sle::LicenseAgreementController;
use Installation::License::Sle::Firstboot::LicenseAgreementController;

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

1;
