# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Network dialog in YaST Firstboot Configuration.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;

sub run {
    $testapi::distri->get_network_settings()
      ->proceed_with_current_configuration();
}

1;
