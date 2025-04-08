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

use Yam::Agama::Pom::GrubMenuBasePage;
use Yam::Agama::Pom::GrubMenuAgamaPage;
use Yam::Agama::Pom::GrubMenuTumbleweedPage;
use Yam::Agama::Pom::GrubEntryEditionPage;
use Yam::Agama::Pom::AgamaUpAndRunningPage;
use Yam::Agama::Pom::RebootPage;
use Yam::Agama::Pom::EnterPassphraseBasePage;
use Yam::Agama::Pom::EnterPassphraseForRootPage;
use Yam::Agama::Pom::EnterPassphraseForSwapPage;

use Utils::Architectures;

sub get_grub_menu_agama {
    return Yam::Agama::Pom::GrubMenuAgamaPage->new({
            grub_menu_base => Yam::Agama::Pom::GrubMenuBasePage->new()
    });
}

sub get_grub_menu_base {
    return Yam::Agama::Pom::GrubMenuBasePage->new();
}

sub get_grub_menu_installed_system {
    return Yam::Agama::Pom::GrubMenuTumbleweedPage->new({
            grub_menu_base => Yam::Agama::Pom::GrubMenuBasePage->new()
    });
}

sub get_grub_entry_edition {
    return is_ppc64le() ? Yam::Agama::Pom::GrubEntryEditionPage->new({
            max_interval => utils::VERY_SLOW_TYPING_SPEED})
      : Yam::Agama::Pom::GrubEntryEditionPage->new();
}

sub get_agama_up_an_running {
    return is_ppc64le() ? Yam::Agama::Pom::AgamaUpAndRunningPage->new({
            timeout_expect_is_shown => 300})
      : Yam::Agama::Pom::AgamaUpAndRunningPage->new();
}

sub get_reboot {
    return Yam::Agama::Pom::RebootPage->new();
}

sub get_enter_passphrase_for_root {
    return Yam::Agama::Pom::EnterPassphraseForRootPage->new({
            enter_passphrase_base => Yam::Agama::Pom::EnterPassphraseBasePage->new()
    });
}

sub get_enter_passphrase_for_swap {
    return Yam::Agama::Pom::EnterPassphraseForSwapPage->new({
            enter_passphrase_base => Yam::Agama::Pom::EnterPassphraseBasePage->new()
    });
}

1;
