# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register the system via local RMT in the installer with server url
# and enabling update repositories.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    $testapi::distri->get_registration()->register_via_rmt({
            server => get_var('RMT_SERVER')});
}

1;
