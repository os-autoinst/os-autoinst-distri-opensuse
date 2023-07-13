# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for the installation to be finished successfully.
# Use TIMEOUT_SCALE so expected installation time can be adjusted
# for slower architectures.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi 'get_var';
use Test::Assert ':all';

sub run {
    my $performing_install = $testapi::distri->get_performing_installation();

    $performing_install->get_performing_installation_page();

    $performing_install->wait_for_installation_popup({
            timeout => 2400,
            timeout_scale => get_var('TIMEOUT_SCALE', 1),
            interval => 2,
            message => 'System reboot popup did not appear'});

    assert_matches(qr/The system will reboot now/,
        $performing_install->get_system_reboot_popup()->text(),
        'System reboot popup is not displayed');
}

1;
