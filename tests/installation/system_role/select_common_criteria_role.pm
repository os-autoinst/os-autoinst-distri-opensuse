# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Select System Role 'Common Criteria' and navigate to next
# screen in SLES.
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    $testapi::distri->get_system_role()->select_system_role('common_criteria');
}

1;
