# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configuration of iSCSI installation
#    check if iBFT is present
#    select iSCSI disk to install system on
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils 'script_output_retry';

# In order to have clear expectations about state of the disk we need to erase it.
# As it could be encrypted or non-encrypted (with or without partitions) making UI to
# react in different ways. It assumes only one iscsi disk already mounted.
sub wipe_iscsi_disk {
    select_console 'install-shell';
    my $disk = script_output_retry("lsscsi | grep 'disk' | awk 'NF>1{print \$NF}'");
    assert_script_run("wipefs -a $disk");
    select_console 'installation';
}

sub run {
    assert_screen 'disk-activation-iscsi';
    send_key 'alt-i';    # configure iscsi disk
    assert_screen 'iscsi-overview', 100;
    send_key 'alt-i';    # iBFT tab
    assert_screen 'iscsi-ibft';
    send_key 'alt-o';    # OK
    assert_screen 'disk-activation-iscsi';
    wipe_iscsi_disk;    # At this point should be mounted and can proceed to erase it
    send_key $cmd{next};
}

1;
