# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: update-alternatives
# Summary: console/update_alternatives test for bsc#969171
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'save_and_upload_log';

my $broken = '/tmp/broken-symlinks.txt';

sub run {
    select_serial_terminal;

    return if script_run('which update-alternatives');

    assert_script_run('update-alternatives --version');
    assert_script_run('update-alternatives --get-selections');

    # find broken links in /etc/alternatives
    script_output("find /etc/alternatives -xtype l | tee $broken");
    if (script_run("test -s $broken") == 0) {
        shift->result('fail');
    }
}

sub post_fail_hook {
    select_console('log-console');
    save_and_upload_log("stat -c '%N' \$(cat $broken)", $broken);
}

sub test_flags {
    return {fatal => 0};
}

1;
