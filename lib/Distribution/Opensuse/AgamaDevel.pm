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
use Yam::Agama::Pom::GrubEntryEdition::GrubEntryEditionPage;
use Yam::Agama::Pom::GrubEntryEdition::ppc64le::GrubEntryEditionPage;
use Yam::Agama::Pom::AgamaUpAndRunningPage;
use Yam::Agama::Pom::RebootPage;

use Utils::Architectures;

sub get_grub_menu {
    return Yam::Agama::Pom::GrubMenuPage->new();
}

sub get_grub_entry_edition {
    my $grub_entry_edition = Yam::Agama::Pom::GrubEntryEdition::GrubEntryEditionPage->new();
    return is_ppc64le() ?
      Yam::Agama::Pom::GrubEntryEdition::ppc64le::GrubEntryEditionPage->new({
            grub_entry_edition => $grub_entry_edition}) :
      $grub_entry_edition;
}

sub get_agama_up_an_running {
    return Yam::Agama::Pom::AgamaUpAndRunningPage->new();
}

sub get_reboot_page {
    return Yam::Agama::Pom::RebootPage->new();
}

1;
