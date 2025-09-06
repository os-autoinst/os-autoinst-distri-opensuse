# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: Validate repos after migration, repos with target version and without
# origin version.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use testapi;
use utils qw(zypper_call);

sub run {
    select_console 'root-console';

    my $origin_version = get_var('VERSION_UPGRADE_FROM');
    my $target_version = get_var('VERSION');
    zypper_call("lr -u");
    assert_script_run("zypper lr -u | grep $target_version");
    die 'The old base system repos existed' if (script_run("zypper lr -u | grep $origin_version") == 0);
}

1;
