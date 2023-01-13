# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register the system via SCC in the installer with registration
# code, optional email and enabling update repositories.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    $testapi::distri->get_registration()->register_via_scc({
            email => get_var('SCC_EMAIL'),
            reg_code => get_var('SCC_REGCODE')});
    $testapi::distri->get_registration()->enable_update_repositories();
}

1;
