# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run the fs_stress testsuite
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use Utils::Logging 'save_and_upload_log';

sub run {
    select_serial_terminal;
    assert_script_run("lsblk -f");
    assert_script_run("df -h");
    assert_script_run("free -h");
    assert_script_run("curl -O " . data_url('file_copy'));
    assert_script_run("chmod +x file_copy");
    assert_script_run("time ./file_copy -j 50 -i 5 -s 100 | tee /tmp/file_copy_100.log", timeout => 600);
    upload_logs('/tmp/file_copy_100.log');
    assert_script_run("time ./file_copy -j 20 -i 5 -s 500 | tee /tmp/file_copy_500.log", timeout => 1200);
    upload_logs('/tmp/file_copy_500.log');
    assert_script_run("time ./file_copy -j 4 -i 5 -s 5000 | tee /tmp/file_copy_5000.log", timeout => 1200);
    upload_logs('/tmp/file_copy_5000.log');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    select_console 'log-console';
    assert_script_run("lsblk -f");
    assert_script_run("df -h");
    assert_script_run("free -h");
    save_and_upload_log('cat /tmp/file_copy_*.log', 'file_copy_all.log');
}

1;
