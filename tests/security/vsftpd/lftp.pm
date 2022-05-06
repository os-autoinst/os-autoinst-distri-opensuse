# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Test vsftpd with ssl enabled
# Maintainer: shawnhao <weixuan.hao@suse.com>
# Tags: poo#108614, tc#1769978

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $user = 'ftpuser';
    my $pwd = 'susetesting';
    my $ftp_file_path = '/srv/ftp/ftpuser/files';

    select_console 'root-console';

    # Install lftp
    zypper_call('in lftp');

    # Start vsftpd server
    systemctl('start vsftpd');

    # Download a file from directory
    enter_cmd("lftp -d -u $user,$pwd -e 'set ftp:ssl-force true' localhost");
    enter_cmd('ls');
    enter_cmd('cd files/');
    enter_cmd('ls');
    enter_cmd('get f1.txt');
    enter_cmd('exit');

    # Check if file has been uploaded
    assert_script_run('ls | grep f1.txt');

    # Upload a file to directory
    assert_script_run('touch f2.txt');
    enter_cmd("lftp -d -u $user,$pwd -e 'set ftp:ssl-force true' localhost");
    enter_cmd('ls');
    enter_cmd('cd files/');
    enter_cmd('ls');
    enter_cmd('put f2.txt');
    enter_cmd('exit');

    # Check if file has been uploaded
    assert_script_run("ls $ftp_file_path | grep f2.txt");
}

1;
