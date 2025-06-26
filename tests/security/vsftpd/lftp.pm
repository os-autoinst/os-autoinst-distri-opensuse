# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Test vsftpd with ssl enabled
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108614, tc#1769978

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);

sub check_hash {
    my ($expected_hash, $calculated_hash) = @_;
    my $message;
    my $result;

    if ($expected_hash eq $calculated_hash) {
        $message = 'Pass: Hash values matched';
        $result = 'ok';
    } else {
        $message = "Error: Hash values did not match. Expected: $expected_hash, Got: $calculated_hash";
        $result = 'fail';
    }

    record_info('Hash Check', $message, result => $result);
}

sub run {
    my $user = 'ftpuser';
    my $pwd = 'susetesting';
    my $ftp_users_path = '/srv/ftp/users';
    my $ftp_served_dir = 'served';
    my $ftp_received_dir = 'received';

    select_serial_terminal;

    # Install lftp
    zypper_call 'in lftp';
    enter_cmd 'echo "set ssl:verify-certificate no" >> /etc/lftp.conf';

    # expect error on failed login
    validate_script_output("lftp -d -u foo,bar -e 'set ftp:ssl-force true' -e ls localhost",
        sub { m/Login failed: 530 Login incorrect./s }, proceed_on_failure => 1);

    # expect error on failed command
    validate_script_output("lftp -d -u $user,$pwd -e suseTESTING localhost",
        sub { /Unknown command/mg }, proceed_on_failure => 1);
    #script_output("lftp -d -u $user,$pwd -e 'set ftp:ssl-force true' localhost", expect => 'Command failed');

    # create a batch of commands to be executed by lftp
    my $lftp_script_file = qq{
        open -u $user,$pwd localhost
        set ftp:ssl-force true
        mkdir test
        cd test
        cd ..
        queue ls
        queue rmdir test
        bye
    };
    assert_script_run("echo '$lftp_script_file' > lftp_script_file.txt");
    # run lftp in batch mode
    assert_script_run("lftp -f lftp_script_file.txt");

    # Login to ftp server for downloading/uploading, first create a file for uploading
    assert_script_run 'echo "QE Security" > f2.txt';
    enter_cmd("lftp -d -u $user,$pwd -e 'set ftp:ssl-force true' localhost");

    # Download file from server
    enter_cmd("get $ftp_served_dir/f1.txt");

    # Upload file to server
    enter_cmd("put -O $ftp_received_dir/ f2.txt");

    # Exit lftp
    enter_cmd('exit');

    # Check if file has been downloaded
    assert_script_run('ls | grep f1.txt');

    # Compare file hashes
    my $hash_orig = script_output(qq[sha256sum "$ftp_users_path/$user/$ftp_served_dir/f1.txt" | awk '{print \$1}']);
    my $hash_downloaded = script_output(qq[sha256sum f1.txt | awk '{print \$1}']);
    check_hash($hash_orig, $hash_downloaded);

    # Check if file has been uploaded
    assert_script_run("ls $ftp_users_path/$user/$ftp_received_dir | grep f2.txt");

    # Compare file hashes
    my $hash_created = script_output(qq[sha256sum f2.txt | awk '{print \$1}']);
    my $hash_uploaded = script_output(qq[sha256sum "$ftp_users_path/$user/$ftp_received_dir/f2.txt" | awk '{print \$1}']);
    check_hash($hash_created, $hash_uploaded);
}

1;
