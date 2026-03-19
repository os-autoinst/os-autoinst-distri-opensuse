# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents SLE 16.0 distribution and
# provides access to its features.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Distribution::Sle::160;
use parent Distribution::Sle::16Latest;
use strict;
use warnings FATAL => 'all';

use Yam::Agama::Pom::GrubMenuSlesPage;

sub get_grub_menu_agama {
    return Yam::Agama::Pom::GrubMenuAgamaPageWithBootFromHD->new({
            grub_menu_base => Yam::Agama::Pom::GrubMenuAgamaBasePage->new()});
}

1;
