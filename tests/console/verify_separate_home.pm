# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: util-linux
# Summary: Verification module. Asserts if /home located on the separate
# partition/volume.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use warnings FATAL => 'all';
use testapi;
use serial_terminal 'select_text_console';

sub run {
    select_text_console;

    assert_script_run("lsblk -n | grep '/home'",
        fail_message => "Fail!\n
        Expected: /home is on separate partition/volume.\n
        Actual: /home is NOT on separate partition/volume."
    );
}

1;
