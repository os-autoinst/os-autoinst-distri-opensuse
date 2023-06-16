# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installer page for handling upgrade of partition with previous installation.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    my $select_update = $testapi::distri->get_select_for_update();
    $select_update->get_select_for_update();
    $select_update->press_next();
}

1;
