# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for New Partition Type
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

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
