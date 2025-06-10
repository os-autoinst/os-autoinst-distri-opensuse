# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: If Full-QR enable most modules, otherwise don't.
# Maintainer: QE Security <none@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    if (check_var('FLAVOR', 'Full-QR') || check_var('FLAVOR', 'Full')) {
        $testapi::distri->get_module_selection()->select_modules(
            [qw(containers desktop development legacy web python)]);
    } else {
        $testapi::distri->get_module_registration()->skip_registration();
    }
}

1;

