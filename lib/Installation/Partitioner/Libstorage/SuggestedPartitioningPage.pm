# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Suggested
# Partitioning Page.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::Libstorage::SuggestedPartitioningPage;

use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::Partitioner::SuggestedPartitioningPage';

sub press_edit_proposal_settings_button {
    my ($self) = @_;
    assert_screen($self->SUGGESTED_PARTITIONING_PAGE);
    send_key('alt-d');
}

sub press_create_partition_setup_button {
    my ($self) = @_;
    assert_screen($self->SUGGESTED_PARTITIONING_PAGE);
    send_key('alt-c');
}
1;
