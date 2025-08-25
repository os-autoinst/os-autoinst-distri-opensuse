# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents current (i.e. latest) SLE 16 distribution and
# provides access to its features.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Sle::16Latest;
use parent Distribution::Sle::AgamaDevel;
use strict;
use warnings FATAL => 'all';

use Yam::Agama::Pom::GrubMenuSlesPage;
use Yam::Agama::Pom::GrubMenuAgamaPage;
use Yam::Agama::Pom::GrubMenuAgamaDeprecatedEntryOrderPage;
use testapi qw(record_soft_failure);
use Utils::Architectures qw(is_ppc64le);

sub get_grub_menu_installed_system {
    my $self = shift;
    return Yam::Agama::Pom::GrubMenuSlesPage->new({grub_menu_base => $self->get_grub_menu_base()});
}

sub get_grub_menu_agama {
    if (is_ppc64le()) {
        record_soft_failure 'bsc#1248161 Boot from hard disk has not been implemented on ppc64le';
        return Yam::Agama::Pom::GrubMenuAgamaDeprecatedEntryOrderPage->new({
                grub_menu_agama => Yam::Agama::Pom::GrubMenuAgamaPage->new({
                        grub_menu_base => Yam::Agama::Pom::GrubMenuBasePage->new()})});
    } else {
        return Yam::Agama::Pom::GrubMenuAgamaPage->new({
                grub_menu_base => Yam::Agama::Pom::GrubMenuBasePage->new()});
    }
}

1;
