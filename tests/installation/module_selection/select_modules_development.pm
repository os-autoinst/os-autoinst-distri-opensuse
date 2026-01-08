# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select SDK and depending desktop modules
#          in "Extension and Module Selection" dialog.
# Medium:  Full (Description Text shows "Directory on the Media")
#
# - Desktop Application Module (will be selected by dependency )
# - Development Tools Module
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_module_selection()->select_module('development');
}

1;
