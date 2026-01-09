# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register the system via local RMT in the installer with server url
# and enabling update repositories.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    $testapi::distri->get_registration()->trust_and_import();
}

1;
