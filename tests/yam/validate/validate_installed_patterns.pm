# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: Validate installed patterns against the list of additional patterns
# selected to be installed during installation.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'consoletest';
use utils 'zypper_call';
use testapi;

sub run {
    select_console 'root-console';

    my @pattern_list = split(/,/, get_var('PATTERNS'));

    zypper_call("search -t pattern");
    zypper_call("search -i -t pattern");
    foreach (@pattern_list) { zypper_call("search -i -t pattern $_"); }
}

1;
