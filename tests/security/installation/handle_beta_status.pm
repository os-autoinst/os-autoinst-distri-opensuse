# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: only check for BETA screen if BETA is enabled
# Maintainer: QE Security <none@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    if (check_var('BETA', '1')) {
        $testapi::distri->get_ok_popup()->accept();
    }
}

1;

