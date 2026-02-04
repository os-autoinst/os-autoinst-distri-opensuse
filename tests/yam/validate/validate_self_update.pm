# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the self-update is performed by Agama via /etc/live-self-update/result
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils qw(systemctl);
use scheduler qw(get_test_suite_data);

sub run {
    select_console 'root-console';

    my $self_update_enabled = get_test_suite_data()->{self_update_enabled};
    if ($self_update_enabled) {
        my $retcode = script_output('cat /run/live-self-update/result');

        # Pass validation if retcode is 0 (All OK) or 4 - ZYPPER_EXIT_ERR_ZYPP A problem is reported by ZYPP library
        if ($retcode != 0 && $retcode != 4) {
            die "Self update did not ended successfully";
        }
    } else {
        systemctl('is-active live-self-update', expect_false => 1);
        assert_script_run("journalctl -t live-self-update | grep \"Self update not configured\"");
    }
}

1;
