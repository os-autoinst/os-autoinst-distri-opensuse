# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module disables separate home partition on Filesystem Options Screen of Guided Setup
# and navigates to the next screen.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'y2_installbase';

sub run {
    $testapi::distri->get_filesystem_options()->do_not_propose_separate_home();
    $testapi::distri->get_filesystem_options()->go_forward();
}

1;
