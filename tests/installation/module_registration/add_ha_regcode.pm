# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: After register HA extension in "Extension
#          and Module Selection" dialog, need to input
#          HA register code at register page
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi qw(save_screenshot get_var);

sub run {
    my $timeout = 60 * get_var('TIMEOUT_SCALE', 1);
    my $regcode = get_var('SCC_REGCODE_HA');
    $testapi::distri->wait_registration_common_regcode_finished({timeout => $timeout, interval => 2, message => 'Page to insert module registration code did not appear'});
    $testapi::distri->get_module_regcode()->add_separate_ha_registration_code($regcode, $timeout);
}

1;
