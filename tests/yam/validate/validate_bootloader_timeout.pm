# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate bootloader timeout value.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';

    my $grub_timeout = get_test_suite_data()->{bootloader_timeout};
    assert_script_run("cat /etc/default/grub");
    assert_script_run("grep GRUB_TIMEOUT=$grub_timeout /etc/default/grub");
}

1;
