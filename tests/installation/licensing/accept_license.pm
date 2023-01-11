# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module to accept license agreement and proceed to the next
#          installer page.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    $testapi::distri->get_license_agreement()->accept_license();
}

1;
