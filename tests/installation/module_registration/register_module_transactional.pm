# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register Transactional Server Module
#          in "Extension and Module Selection" dialog
# Medium:  Online (you see the "Hide Development versions" checkbox)
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_module_registration()->register_module('tsm');
}

1;
