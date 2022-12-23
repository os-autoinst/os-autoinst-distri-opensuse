# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Skip extension and module registration
#          in "Extension and Module Selection" dialog
# Medium:  Online (you see the "Hide Development versions" checkbox)
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_module_registration()->skip_registration();
}

1;
