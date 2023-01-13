# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Preparing Hard Disk
# Page of Expert Partitioner that are unique for Libstorage.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::Libstorage::PreparingHardDiskPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    PREPARING_HARD_DISK_PAGE => 'preparing-hard-disk-page'
};

sub select_custom_partitioning_radiobutton {
    assert_screen(PREPARING_HARD_DISK_PAGE);
    send_key('alt-c');
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(PREPARING_HARD_DISK_PAGE);
}

1;
