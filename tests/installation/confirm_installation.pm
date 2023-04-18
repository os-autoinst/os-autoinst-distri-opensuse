# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module confirms the popup for installation.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    my $install_popup = $testapi::distri->get_ok_popup_controller();
    $install_popup->accept();
}

1;
