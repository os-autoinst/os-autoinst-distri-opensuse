# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: rsync coreutils
# Summary: This module creates files that are synced afterwards using rsync.
# - Install rsync (if not jeos)
# - Create three test directories and populate with files, scripts and compressed files
# - Run "rsync -avzr /tmp/rsync_test_folder_a/ root@localhost:/tmp/rsync_test_folder_b; echo $? > /tmp/rsync_return_code.txt"
# - Check the operation return code and md5sum from files transfered
# - Check that rsync with option -H (hard links) works correctly
# Maintainer: Ondřej Pithart <ondrej.pithart@suse.com>


use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_opensuse is_sle is_jeos);

sub run {
    select_serial_terminal;
    # try to install rsync if the test does not run on JeOS
    if (!is_jeos) {
        zypper_call('-t in rsync', dumb_term => 1);
    }

    # create the folders and files that will be synced
    assert_script_run('mkdir /tmp/rsync_test_folder_a');
    assert_script_run('mkdir /tmp/rsync_test_folder_b');
    assert_script_run('mkdir /tmp/rsync_test_folder_c');
    assert_script_run('echo "hard link text" > /tmp/rsync_test_folder_c/text.txt');
    assert_script_run('ln /tmp/rsync_test_folder_c/text.txt /tmp/rsync_test_folder_c/hard-link.txt');
    assert_script_run('echo rsync_test > /tmp/rsync_test_folder_a/rsync_test_file');
    assert_script_run("echo '#!/bin/sh\\necho Hello World' > /tmp/rsync_test_folder_a/rsync_test_sh.sh");
    assert_script_run('tar -cvf /tmp/rsync_test_folder_a/rsync_test_tar.tar /tmp/rsync_test_folder_a/rsync_test_file');

    my $md5_initial_file = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_file');
    my $md5_initial_sh = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_sh.sh');
    my $md5_initial_tar = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_tar.tar');

    enter_cmd("rsync -avzr /tmp/rsync_test_folder_a/ root\@localhost:/tmp/rsync_test_folder_b; echo \$\? > /tmp/rsync_return_code.txt");
    assert_script_run('time sync');

    # keep the md5 hash value of the synced file and folder
    my $md5_synced_file = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_file');
    my $md5_synced_sh = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_sh.sh');
    my $md5_synced_tar = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_tar.tar');

    # compare the hash values
    die("MD5 hash value of the synced text file is different from the initial one") unless ($md5_initial_file == $md5_synced_file);
    die("MD5 hash value of the synced sh file is different from the initial one") unless ($md5_initial_sh == $md5_synced_sh);
    die("MD5 hash value of the synced tar file is different from the initial one") unless ($md5_initial_tar == $md5_synced_tar);

    # test that option -H works correctly
    # from https://bugzilla.suse.com/show_bug.cgi?id=1235895 and https://github.com/RsyncProject/rsync/issues/697
    assert_script_run('rsync -av -H /tmp/rsync_test_folder_c /tmp/rsync_test_folder_out');
    # check that inode numbers match (hard link was preserved)
    assert_script_run('cd /tmp/rsync_test_folder_out/rsync_test_folder_c; [ text.txt -ef hard-link.txt ]; cd -');
}

sub post_run_hook {
    assert_script_run('rm -rf /tmp/rsync_test_folder_*');
    assert_script_run('rm /tmp/rsync_return_code.txt');

    if (is_opensuse) {
        systemctl 'restart sshd';
    }
}

1;
