# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register Application module
#          in "Extension and Module Selection" dialog
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi qw(save_screenshot get_required_var);

sub run {
    my @scc_addons = grep($_, split(/,/, get_required_var('SCC_ADDONS')));
    $testapi::distri->get_module_registration()->register_extension_and_modules([@scc_addons]);
    save_screenshot;
}

1;
