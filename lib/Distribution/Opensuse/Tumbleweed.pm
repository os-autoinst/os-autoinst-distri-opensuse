# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class represents Tumbleweed distribution and provides access to
# its features.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Distribution::Opensuse::Tumbleweed;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';
use Installation::Partitioner::LibstorageNG::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::ExpertPartitionerController;

sub get_partitioner {
    return Installation::Partitioner::LibstorageNG::GuidedSetupController->new();
}

sub get_expert_partitioner {
    return Installation::Partitioner::LibstorageNG::ExpertPartitionerController->new();
}

1;
