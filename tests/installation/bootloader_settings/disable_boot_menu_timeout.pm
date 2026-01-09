# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable grub timeout from the Installer
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use version_utils qw(is_bootloader_grub2);

sub run {
    $testapi::distri->get_installation_settings()->access_booting_options();
    if (is_bootloader_grub2) {
        $testapi::distri->get_bootloader_settings()->disable_grub_timeout();
    } else {
        $testapi::distri->get_bootloader_settings()->bls_disable_timeout();
    }
}

1;
