# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module just accepts default configuration on
# Partitioning Scheme Screen of Guided Setup.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'y2_installbase';

sub run {
    $testapi::distri->get_partitioning_scheme()->go_forward();
}

1;
