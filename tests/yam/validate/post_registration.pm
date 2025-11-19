# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check the system is unregistered and register it via suseconnect tool.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>
use base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run "SUSEConnect -s | grep 'Not Registered'";
    assert_script_run "SUSEConnect --status-text";
    my $url_paras = get_var('SCC_URL') ? " --url " . get_var('SCC_URL') : '';
    assert_script_run "SUSEConnect -r " . get_var('SCC_REGCODE') . $url_paras, 180;
    assert_script_run "SUSEConnect --status-text | grep -v 'Not Registered'";
    assert_script_run "zypper lr | grep SLE-Product-SLES-" . get_var('VERSION');
    assert_script_run "SUSEConnect --list-extensions";
    assert_script_run "SUSEConnect -d || SUSEConnect --cleanup";
    assert_script_run "SUSEConnect -s | grep 'Not Registered'";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
