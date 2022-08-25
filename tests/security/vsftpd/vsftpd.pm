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
    my $ftp_users_path = '/srv/ftp/users';
    my $ftp_served_dir = 'served';
    my $ftp_received_dir = 'received';
    my $user = 'ftpuser';
    my $pwd = 'susetesting';

    select_console 'root-console';

    # Change to ftpuser for downloading and uploading
    enter_cmd("su - $user");

    # Download a file with various ssl methods
    assert_script_run("curl -v -k --ssl ftp://$user:$pwd\@localhost/served/f1.txt -o $ftp_users_path/$user/$ftp_received_dir/f1.txt");

    # Upload a file
    assert_script_run("curl -v -k --ssl ftp://$user:$pwd\@localhost/served/f2.txt -T $ftp_users_path/$user/$ftp_received_dir/f1.txt");

    # Clean console for next test
    enter_cmd('exit');
    enter_cmd('cd && clear');
}

1;
