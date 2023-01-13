# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module selects Ext3 Filesystem for Root Partition on
# Filesystem Options Screen of Guided Setup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_filesystem_options()->select_root_filesystem_type('ext3');
    $testapi::distri->get_filesystem_options()->go_forward();
}

1;
