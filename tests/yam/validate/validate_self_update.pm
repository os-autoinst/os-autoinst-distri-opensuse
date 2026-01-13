# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the self-update is performed by Agama via /etc/live-self-update/result
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';
    my $retcode = script_output('cat /run/live-self-update/result');

    # Pass validation if retcode is 0 (All OK) or 4 - ZYPPER_EXIT_ERR_ZYPP A problem is reported by ZYPP library
    if ($retcode != 0 && $retcode != 4) {
        die "Self update did not ended successfully";
    }
}

1;
