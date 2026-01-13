# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register Transactional Server Module
#          in "Extension and Module Selection" dialog
# Medium:  Online (you see the "Hide Development versions" checkbox)
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_module_registration()->register_module('tsm');
}

1;
