# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Activates a device in DASD disk management page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    my $dasd_disk_management = $testapi::distri->get_dasd_disk_management();
    $dasd_disk_management->activate_device('0.0.0150');
    $dasd_disk_management->accept_configuration();
}

1;
