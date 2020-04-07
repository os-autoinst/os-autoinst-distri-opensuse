# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Provide functionality for hpc tests.
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package hpc::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub get_mpi() {
    my $mpi = get_required_var('MPI');

    if ($mpi eq 'openmpi3') {
        if (is_sle('<15')) {
            $mpi = 'openmpi';
        } elsif (is_sle('<15-SP2')) {
            $mpi = 'openmpi2';
        }
    }

    return $mpi;
}

1;
