# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Test vsftpd with ssl enabled
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108614, tc#1769978, poo#209403

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);

sub check_hash {
    my ($expected_hash, $calculated_hash) = @_;

    die "Hash values did not match. Expected: $expected_hash, Got: $calculated_hash"
      unless $expected_hash eq $calculated_hash;
    record_info('Hash Check', 'Pass: Hash values matched');
}

# Set ssl_tlsv1_3 in vsftpd.conf to YES or NO, restart vsftpd and wait for it
sub set_vsftpd_tls13 {
    my ($value) = @_;

    assert_script_run("sed -i 's/^ssl_tlsv1_3=.*/ssl_tlsv1_3=$value/' /etc/vsftpd.conf");
    systemctl('restart vsftpd');
    script_retry("ss -Hltn 'sport = :21' | grep -q LISTEN", delay => 1, retry => 30, timeout => 5);
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

    # Create a batch of commands to be executed by lftp.
    # Do not use "queue": queued jobs make lftp move to the background on "bye",
    # and then the exit status is always 0. With cmd:fail-exit, lftp stops at
    # the first failed command and returns a non-zero exit status.
    my $lftp_script_file = qq{
        set cmd:fail-exit true
        set ftp:ssl-force true
        open -u $user,$pwd localhost
        mkdir test
        cd test
        cd ..
        ls
        rmdir test
        bye
    };
    script_output("echo '$lftp_script_file' > lftp_script_file.txt");
    # run lftp in batch mode
    assert_script_run("lftp -f lftp_script_file.txt");

    # Download and upload in batch mode with one try for each transfer. Then a
    # failed transfer stops lftp with a non-zero exit status. In interactive
    # mode, lftp retries for minutes and reads the next test commands as input.
    my $lftp = "lftp -d -u $user,$pwd -e 'set ftp:ssl-force true; set cmd:fail-exit true; set net:max-retries 1;";

    # Download file from server
    assert_script_run("$lftp get $ftp_served_dir/f1.txt; bye' localhost", timeout => 90);

    # Upload file to server, first create a file for uploading
    assert_script_run 'echo "QE Security" > f2.txt';
    my $put = "$lftp put -O $ftp_received_dir/ f2.txt; bye' localhost";
    if (script_run("$put > lftp_put.log 2>&1", timeout => 90)) {
        my $log = script_output('cat lftp_put.log', proceed_on_failure => 1);
        die "lftp upload failed:\n$log" unless $log =~ /426 Failure reading network stream/;
        # lftp closes the TLS 1.3 data connection with unread session tickets.
        # The kernel then sends RST, the close_notify is lost and vsftpd
        # rejects the upload. Upload again with TLS 1.2 to test the rest.
        record_soft_failure('bsc#1289120 - lftp does not close the TLS 1.3 data connection correctly, vsftpd answers 426');
        record_info('lftp put log', $log);
        set_vsftpd_tls13('NO');
        assert_script_run($put, timeout => 90);
        set_vsftpd_tls13('YES');
    }

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
