# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module confirms the popup for installation.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'y2_installbase';
use version_utils 'is_sle';

sub run {
    # For SLE 15 SP4 tests that have the Legacy module added during installation, there is
    # additional licence popup that is handled by the following function.
    if (!(get_var("PATTERNS") =~ /minimal/) && (get_var("SCC_ADDONS") =~ /legacy/) && (is_sle("=15-SP4"))) {
        my $package_license_popup = $testapi::distri->get_accept_popup_controller();
        $package_license_popup->wait_accept_popup({
                timeout => 3000,
                interval => 2,
                message => 'Accept license popup did not appear'});
        save_screenshot;
        $package_license_popup->accept();
    }
    my $install_popup = $testapi::distri->get_ok_popup_controller();
    $install_popup->accept();
}

1;
