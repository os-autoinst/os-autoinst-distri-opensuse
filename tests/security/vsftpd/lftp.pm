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

sub check_md5 {
    if ($_[0] == $_[1]) {
        record_info('Pass: ', 'md5 values matched');
    } else {
        record_info('Error: ', 'md5 values did not match');
    }
}

sub run {
    my $user = 'ftpuser';
    my $pwd = 'susetesting';
    my $ftp_file_path = '/srv/ftp/ftpuser/files';

    select_console 'root-console';

    # Install lftp
    zypper_call('in lftp');

    # Start vsftpd server
    systemctl('start vsftpd');

    # Login to ftp server for downloading/uploading, first create a file for uploading
    assert_script_run('touch f2.txt');
    enter_cmd("lftp -d -u $user,$pwd -e 'set ftp:ssl-force true' localhost");
    enter_cmd('cd files/');

    # Download file from server
    enter_cmd('get f1.txt');

    # Upload file to server
    enter_cmd('put f2.txt');
    enter_cmd('exit');

    # Check if file has been downloaded
    assert_script_run('ls | grep f1.txt');

    # Check md5 of original file in ftp server and downloaded one
    my $md5_orig = script_output("md5sum $ftp_file_path/f1.txt");
    my $md5_downloaded = script_output('md5sum f1.txt');
    check_md5($md5_orig, $md5_downloaded);

    # Check if file has been uploaded
    assert_script_run("ls $ftp_file_path | grep f2.txt");

    # Check md5 for created file and uploaded one
    my $md5_created = script_output('md5sum f2.txt');
    my $md5_uploaded = script_output("md5sum $ftp_file_path/f2.txt");
    check_md5($md5_created, $md5_uploaded);
}

1;
