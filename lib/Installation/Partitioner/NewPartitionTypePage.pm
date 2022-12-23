# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for New Partition Type
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::NewPartitionTypePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    NEW_PARTITION_TYPE_PAGE => 'partitioning-type'
};

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(NEW_PARTITION_TYPE_PAGE);
}

1;
