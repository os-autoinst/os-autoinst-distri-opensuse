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
use testapi qw(save_screenshot get_var);

sub run {
    my @scc_addons = split ',', get_var('SCC_ADDONS');
    $testapi::distri->get_module_registration()->register_extension_and_modules([@scc_addons]);
    save_screenshot;

    # when some module (e.g. workstation extension) requires registration, provide separate code
    my $timeout = 60 * get_var('TIMEOUT_SCALE', 1);
    my $regcode = get_var('SCC_REGCODE_WE');
    $testapi::distri->get_module_regcode()->add_separate_registration_code($regcode, $timeout);
    save_screenshot;

    # confirm to trust the untrusted GPG key
    $testapi::distri->get_module_regcode()->trust_gnupg_key();
}

1;
