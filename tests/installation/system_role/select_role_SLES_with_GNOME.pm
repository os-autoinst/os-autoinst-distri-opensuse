# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Select System Role 'SLES with Gnome' and navigate to next screen
# in SLES.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    $testapi::distri->get_system_role_controller()->select_system_role('SLES_with_GNOME');
}

1;
