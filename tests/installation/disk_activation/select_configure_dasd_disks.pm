# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Selects DASD disk configuration in disk activation page
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    my $disk_activation = $testapi::distri->get_disk_activation();
    $disk_activation->configure_dasd_disks();
}

1;
