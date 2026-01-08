# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Customer Center dialog in YaST Firstboot Configuration
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_firstboot_basetest';

sub run {
    $testapi::distri->get_registration_of_registered_system()
      ->proceed_with_current_configuration();
}

1;
