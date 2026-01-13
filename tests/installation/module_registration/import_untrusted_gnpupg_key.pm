# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: import GPG key
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_module_regcode()->trust_gnupg_key();
}

1;
