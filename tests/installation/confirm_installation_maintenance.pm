# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module confirms the popup for installation and additionally, in case
#          there is an update of a non-free license package, accepts the extra license popup
#          that will appear before the confirm installation popup.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    my $install_popup = $testapi::distri->get_ok_popup();
    my $license_popup = $testapi::distri->get_license_popup();
    # The first check is for the confirm installation popup, in order to save time as
    # extra license popups will rarely appear.
    unless ($install_popup->is_ok_popup_visible()) {
        save_screenshot();
        $license_popup->accept();
    }
    $install_popup->accept();
}

1;
