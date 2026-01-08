# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Network dialog in YaST Firstboot Configuration.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_firstboot_basetest';

sub run {
    $testapi::distri->get_network_settings()
      ->proceed_with_current_configuration();
}

1;
