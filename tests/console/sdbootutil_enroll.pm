# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Package: sdbootutil
# Summary: Enroll TPM to unlock encrypted disk
# Maintainer: Santiago Zarate <santiago.zarate@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';

sub run {
    select_console 'root-console';
    script_run_interactive(
        "sdbootutil enroll --method tpm2;",
        [
            {
                prompt => qr/Password for.*/m,
                string => "$testapi::password\n",
            },
        ],
        60
    );

    set_var("RUNTIME_TPM_ENROLLED", 1);
    power_action('reboot', textmode => 1, keepconsole => 1);
    shift->wait_boot(bootloader_time => 300);
    # since this is a consoletest, allow post_run hook to run freely
    # by switching back to root-console
    select_console 'root-console';
}

1;
