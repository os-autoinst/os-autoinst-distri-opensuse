# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module to accept license agreement and proceed to the next
#          installer page.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    $testapi::distri->get_license_agreement()->accept_license();
}

1;
