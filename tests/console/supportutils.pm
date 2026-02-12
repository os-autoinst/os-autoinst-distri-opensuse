# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: supportutils
# Summary: Test is files created by supportconfig are readable and contain some basic data.
# - Delete any previously existing supportconfig data
# - Run supportconfig -B test
# - Check for supportconfig contents
# - Cleanup supportconfig data
# Maintainer: Juraj Hura <jhura@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use upload_system_log 'upload_supportconfig_log';
use version_utils 'is_sle';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    zypper_call('in supportutils') if script_run('rpm -q supportutils');
    my $options = get_var('SUPPORTCOFIG_OPTIONS', '');
    assert_script_run "rm -rf /var/log/nts_* /var/log/scc_* ||:";
    upload_supportconfig_log(file_name => 'test', options => $options, timeout => 2000);

    my $scc_file = '/var/log/scc_test.txz';
    # bcc#1166774
    if (script_run("test -e $scc_file") == 0) {
        assert_script_run "xz -dc $scc_file | tar -xf -";
        assert_script_run 'cd scc_test';
    } else {
        assert_script_run "cd nts_test";
    }

    # Check few file whether expected content is there.
    # we just compare the first line after /proc/cmdline in boot.txt
    # with the content in /proc/cmdline.
    if (is_sle('>=16')) {
        # in SLE 16 we need to compare only the first part because the rest is stripped by supportconfig due to live.password being present
        assert_script_run(q(awk '/^# \/proc\/cmdline/{getline; print $1 " " $2 " " $3; exit}' boot.txt > cmdline_cleaned_output.txt));
        assert_script_run(q(awk '{print $1 " " $2 " " $3}' /proc/cmdline > cmdline_system.txt));
        assert_script_run(q(diff cmdline_cleaned_output.txt cmdline_system.txt));
    } else {
        assert_script_run(q(diff <(awk '/^# \/proc\/cmdline/{getline; print; exit}' boot.txt) /proc/cmdline));
    }
    assert_script_run "grep -q -f /etc/os-release basic-environment.txt";

    assert_script_run "cd ..";
    assert_script_run "rm -rf nts_* scc_* ||:";
}

1;
