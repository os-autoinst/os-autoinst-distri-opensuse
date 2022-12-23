# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that "resume=" kernel parameter is absent in the list of default parameters.
# This kernel parameter enables hibernation, it is not supported for all backends.
# See https://bugzilla.suse.com/show_bug.cgi?id=1188731

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run("grep -v 'resume=' /proc/cmdline", fail_message => "resume parameter found in /proc/cmdline");
}

1;
