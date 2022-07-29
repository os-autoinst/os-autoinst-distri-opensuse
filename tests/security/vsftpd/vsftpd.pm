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
    my $ftp_file_path = '/srv/ftp/ftpuser/files';
    my $user = 'ftpuser';

    select_console 'root-console';

    # Change to ftpuser for downloading and uploading
    enter_cmd("su - $user");

    # Download a file with various ssl methods
    assert_script_run('curl -v -k --ssl ftp://ftpuser:test@localhost/files/f1.txt -o f1.txt');

    # Upload a file
    assert_script_run("cp $ftp_file_path/f1.txt $ftp_file_path/f2.txt");
    assert_script_run("curl -v -k --ssl ftp://ftpuser:test\@localhost/files/ -T $ftp_file_path/f2.txt");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
