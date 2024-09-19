# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Agama Devel distribution (not really a real distribution!)
# for integration tests using the current state of code at GitHub for Agama.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Opensuse::AgamaDevel;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';

use Yam::Agama::Pom::GrubMenuPage;
use Yam::Agama::Pom::GrubEntryEditionPage;
use Yam::Agama::Pom::AgamaUpAndRunningPage;
use Yam::Agama::Pom::RebootPage;
use Yam::Agama::Pom::RebootTextmodePage;

use Utils::Architectures;

sub get_grub_menu {
    return Yam::Agama::Pom::GrubMenuPage->new();
}

sub get_grub_entry_edition {
    return is_ppc64le() ? Yam::Agama::Pom::GrubEntryEditionPage->new({
            number_kernel_line => 3,
            max_interval => utils::VERY_SLOW_TYPING_SPEED})
      : Yam::Agama::Pom::GrubEntryEditionPage->new();
}

sub get_agama_up_an_running {
    return Yam::Agama::Pom::AgamaUpAndRunningPage->new();
}

sub get_reboot_page {
    if (is_s390x()) {
        return Yam::Agama::Pom::RebootTextmodePage->new();
    }
    else {
        return Yam::Agama::Pom::RebootPage->new();
    }

}

1;
