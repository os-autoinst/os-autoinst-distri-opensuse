# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Stop timeout for system reboot now.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_performing_installation()->stop_timeout_system_reboot_now();
}

1;
