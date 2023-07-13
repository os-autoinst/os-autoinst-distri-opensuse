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
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_module_selection()->select_modules(
        [qw(containers desktop development legacy web)]);
}

1;
