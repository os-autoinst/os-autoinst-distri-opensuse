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
use strict;
use warnings;
use testapi;
use upload_system_log 'upload_supportconfig_log';

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    select_console 'root-console';
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
    assert_script_run(q(diff <(awk '/^# \/proc\/cmdline/{getline; print; exit}' boot.txt) /proc/cmdline));
    assert_script_run "grep -q -f /etc/os-release basic-environment.txt";

    assert_script_run "cd ..";
    assert_script_run "rm -rf nts_* scc_* ||:";
}

1;
