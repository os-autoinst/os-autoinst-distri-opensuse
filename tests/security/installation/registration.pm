# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: If Full-QR don't register the system, otherwise do the registration.
# Maintainer: QE Security <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    if (check_var('FLAVOR', 'Full-QR') || check_var('FLAVOR', 'Full')) {
        $testapi::distri->get_registration()->skip_registration();
    } else {
        $testapi::distri->get_registration()->register_via_scc({
                email => get_var('SCC_EMAIL'),
                reg_code => get_var('SCC_REGCODE')});
        $testapi::distri->get_registration()->enable_update_repositories();
    }
}

1;
