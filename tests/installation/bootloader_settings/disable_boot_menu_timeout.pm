# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable grub timeout from the Installer
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_booting_options();
    $testapi::distri->get_bootloader_settings()->disable_grub_timeout();
}

1;
