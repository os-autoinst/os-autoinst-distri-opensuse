# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module confirms the popup for Package license.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    my $package_license_popup = $testapi::distri->get_accept_popup_controller();
    $package_license_popup->wait_accept_popup({
            timeout => 3000,
            interval => 2,
            message => 'Accept license popup did not appear'});

    $package_license_popup->accept();
}

1;
