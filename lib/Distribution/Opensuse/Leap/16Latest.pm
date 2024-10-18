# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents current (i.e. latest) SLE 16 distribution and
# provides access to its features.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Opensuse::Leap::16Latest;
use parent Distribution::Opensuse::AgamaDevel;
use strict;
use warnings FATAL => 'all';

use Yam::Agama::Pom::GrubMenuBasePage;
use Yam::Agama::Pom::GrubMenuLeapPage;
use Yam::Agama::Pom::GrubMenuBaseBug1231658Page;
use Utils::Architectures;

sub get_grub_menu_installed_system {
    if (is_aarch64) {
        return Yam::Agama::Pom::GrubMenuLeapPage->new(
            {
                grub_menu_base => Yam::Agama::Pom::GrubMenuBaseBug1231658Page->new()});
    }
    else {
        return Yam::Agama::Pom::GrubMenuLeapPage->new(
            {
                grub_menu_base => Yam::Agama::Pom::GrubMenuBasePage->new()});
    }
}

1;
