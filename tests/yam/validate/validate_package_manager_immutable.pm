# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate behaviour of transactional filesystem
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    validate_script_output("transactional-update -h", qr /Applies package updates to a new snapshot/,
        fail_message => 'Failed to execute help command for transactional update.');
    assert_script_run('zypper in patterns-base-transactional_base 2>&1 | grep "This is a transactional-server"');
}

1;
