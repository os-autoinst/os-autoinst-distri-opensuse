# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents current (i.e. latest) SLE 16 distribution and
# provides access to its features.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Distribution::Sle::16Latest;
use parent Distribution::Sle::AgamaDevel;
use strict;
use warnings FATAL => 'all';

use Yam::Agama::Pom::GrubMenuSlesPage;

sub get_grub_menu_installed_system {
    my $self = shift;
    return Yam::Agama::Pom::GrubMenuSlesPage->new({grub_menu_base => $self->get_grub_menu_base()});
}

1;
