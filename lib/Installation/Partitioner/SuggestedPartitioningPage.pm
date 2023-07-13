# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Suggested
# Partitioning Page, that are common for all the versions of the page (e.g. for
# both Libstorage and Libstorage-NG).

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::SuggestedPartitioningPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';

use constant {
    SUGGESTED_PARTITIONING_PAGE => 'inst-suggested-partitioning-step',
    LVM_ENCRYPTED_PARTITION_IN_LIST => 'partitioning-encrypt-activated',
    LVM_PARTITION_IN_LIST => 'partition-lvm-new-summary',
    IGNORED_EXISTING_ENCRYPTED_PARTITION_IN_LIST => 'partitioning-encrypt-ignored-existing'
};

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(SUGGESTED_PARTITIONING_PAGE);
}

sub assert_encrypted_partition_with_lvm_shown_in_the_list {
    assert_screen(LVM_ENCRYPTED_PARTITION_IN_LIST);
}

sub assert_partition_with_lvm_shown_in_the_list {
    assert_screen(LVM_PARTITION_IN_LIST);
}

sub check_existing_encrypted_partition_ignored {
    if (check_screen(IGNORED_EXISTING_ENCRYPTED_PARTITION_IN_LIST, 60)) {
        record_info 'bsc#993247 https://fate.suse.com/321208',
          'activated encrypted partition will not be recreated as encrypted';
    }
}

1;
