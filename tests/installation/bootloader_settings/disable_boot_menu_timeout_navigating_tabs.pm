# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable grub timeout from the Installer to catch regression of bsc#1208266
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_booting_options();
    $testapi::distri->get_bootloader_settings()->disable_grub_timeout_navigating_tabs();
}

1;
