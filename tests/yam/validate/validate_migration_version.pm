# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: Validate os version after migration.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    my $version = get_var('VERSION');
    assert_script_run("cat /etc/os-release");
    assert_script_run("grep \'VERSION=\"$version\"\' /etc/os-release");
}

1;
