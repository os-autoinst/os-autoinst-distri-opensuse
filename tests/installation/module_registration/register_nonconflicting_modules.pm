# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register non-conflicting modules along with preselected modules
#          in "Extension and Module Selection" dialog
# Medium:  Online (you see the "Hide Development versions" checkbox)
#
# - Basesystem (preselcted)
# - Server Applications (preselected)
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
    $testapi::distri->get_module_registration()->register_extension_and_modules(
        [qw(contm desktop sdk legacy script)]);
}

1;
