# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configuration of iSCSI installation
#    check if iBFT is present
#    select iSCSI disk to install system on
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'y2_installbase';
use testapi;
use partition_setup 'take_first_disk';

sub run {
    # Select iSCSI disk for installation
    take_first_disk iscsi => 1;
}

1;
