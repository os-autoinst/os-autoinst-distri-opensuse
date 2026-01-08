# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable plymouth in Boot Loader Settings during installation.
# Required in PowerVM.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_booting_options();
    $testapi::distri->get_bootloader_settings()->disable_plymouth();
}

1;
