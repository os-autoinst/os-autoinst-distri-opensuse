# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles YaST Firstboot Host Name Configuration
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_firstboot_basetest';

sub run {
    $testapi::distri->get_firstboot_host_name()->proceed_with_current_configuration();
}

1;
