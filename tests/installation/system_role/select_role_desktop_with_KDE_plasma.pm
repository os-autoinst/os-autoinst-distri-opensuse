# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Select System Role 'Desktop with KDE Plasma' and navigate to
# next screen in openSUSE.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_system_role()->select_system_role('desktop_with_KDE_plasma');
}

1;
