# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Test vsftpd with ssl enabled
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108614, tc#1769978

use base 'opensusebasetest';
use testapi;
use utils;
use version_utils 'has_selinux';

sub run {
    my $ftp_users_path = '/srv/ftp/users';
    my $ftp_served_dir = 'served';
    my $ftp_received_dir = 'received';
    my $user = 'ftpuser';
    my $pwd = 'susetesting';

    select_console 'root-console';
    if (has_selinux) {
        assert_script_run('setsebool -P ftpd_full_access 1');
        assert_script_run("restorecon -R $ftp_users_path");
    }

    # Change to ftpuser
    enter_cmd("su - $user");

    # Download a file using atomatic ssl method selection
    assert_script_run("curl -v -k --ssl ftp://$user:$pwd\@localhost/served/f1.txt -o $ftp_users_path/$user/$ftp_received_dir/f1.txt");

    # Upload a file using atomatic ssl method selection
    assert_script_run("curl -v -k --ssl ftp://$user:$pwd\@localhost/served/f2.txt -T $ftp_users_path/$user/$ftp_received_dir/f1.txt");

    # Use a specific cipher
    assert_script_run("curl -v -k --ssl --ciphers 'ECDHE-RSA-AES128-GCM-SHA256' ftp://$user:$pwd\@localhost/served/f1.txt -o $ftp_users_path/$user/$ftp_received_dir/f1_cipher.txt");

    # Use passive mode
    assert_script_run("curl -v -k --ssl --ftp-pasv ftp://$user:$pwd\@localhost/served/f1.txt -o $ftp_users_path/$user/$ftp_received_dir/f1_passive.txt");

    # Clean console for next test
    enter_cmd('exit');
    enter_cmd('cd && clear');
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
