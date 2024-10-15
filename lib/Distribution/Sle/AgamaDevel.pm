# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Agama Devel distribution (not really a real distribution!)
# for integration tests using the current state of code at GitHub for Agama.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Sle::AgamaDevel;
use strict;
use warnings FATAL => 'all';
use parent 'Distribution::Opensuse::Leap::16Latest';

use Yam::Agama::Pom::GrubMenuBasePage;
use Yam::Agama::Pom::GrubMenuSlesPage;
use Yam::Agama::Pom::AgamaUpAndRunningSlePage;

sub get_grub_menu_installed_system {
    return Yam::Agama::Pom::GrubMenuSlesPage->new({
            grub_menu_base => Yam::Agama::Pom::GrubMenuBasePage->new()
    });
}

sub get_agama_up_an_running {
    return Yam::Agama::Pom::AgamaUpAndRunningSlePage->new();
}

1;
