# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Partitioning Scheme
# Page in Guided Setup.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::PartitioningSchemePage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';

use constant {
    PARTITIONING_SCHEME_PAGE => 'inst-partitioning-scheme',
    ENABLED_LVM_CHECKBOX => 'inst-partitioning-lvm-enabled'
};

sub select_logical_volume_management_checkbox {
    assert_screen(PARTITIONING_SCHEME_PAGE);
    send_key('alt-e');
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(PARTITIONING_SCHEME_PAGE);
}

sub select_enable_disk_encryption_checkbox {
    assert_screen(PARTITIONING_SCHEME_PAGE);
    send_key('alt-a');
}

sub enter_password {
    assert_screen(PARTITIONING_SCHEME_PAGE);
    send_key('alt-p');
    type_password();
}

sub enter_password_confirmation {
    assert_screen(PARTITIONING_SCHEME_PAGE);
    send_key('alt-v');
    type_password();
}

1;
