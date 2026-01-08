# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select nonconflicting modules
#          in "Extension and Module Selection" dialog.
# Medium:  Full (Description Text shows "Directory on the Media")
#
# - Containers Module
# - Desktop Application Module
# - Development Tools Module
# - Legacy Module
# - Web and Scripting Module
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_module_selection()->select_modules(
        [qw(containers desktop development legacy web python)]);
}

1;
