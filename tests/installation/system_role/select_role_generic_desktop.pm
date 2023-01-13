# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Select System Role 'Generic Desktop' and navigate to next screen
# in openSUSE.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    $testapi::distri->get_system_role_controller()->select_system_role('generic_desktop');
}

1;
