# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles page for detection of previously used repositories.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_previously_used_repos()->next();
}

1;
