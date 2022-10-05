# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: rsync coreutils
# Summary: This module creates files that are synced afterwards using rsync.
# - Install rsync (if not jeos)
# - Create two test directories and populate with files, scripts and compressed
# files
# - Run "rsync -avzr /tmp/rsync_test_folder_a/ root@localhost:/tmp/rsync_test_folder_b; echo $? > /tmp/rsync_return_code.txt"
# - Check the operation return code and md5sum from files transfered
# Maintainer: Ciprian Cret <ccret@suse.com>


use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_opensuse is_sle is_jeos);
use Utils::Backends qw(is_svirt_except_s390x);

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    # try to install rsync if the test does not run on JeOS
    if (!is_jeos) {
        zypper_call('-t in rsync', dumb_term => 1);
    }

    # create the folders and files that will be synced
    assert_script_run('mkdir /tmp/rsync_test_folder_a');
    assert_script_run('mkdir /tmp/rsync_test_folder_b');
    assert_script_run('echo rsync_test > /tmp/rsync_test_folder_a/rsync_test_file');
    assert_script_run("echo '#!/bin/sh\\necho Hello World' > /tmp/rsync_test_folder_a/rsync_test_sh.sh");
    assert_script_run('tar -cvf /tmp/rsync_test_folder_a/rsync_test_tar.tar /tmp/rsync_test_folder_a/rsync_test_file');

    my $md5_initial_file = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_file');
    my $md5_initial_sh = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_sh.sh');
    my $md5_initial_tar = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_tar.tar');

    # we have an issue with 'authenticate the localhost' on svirt backend
    if (is_svirt_except_s390x) {
        my $filename = "/root/.ssh/known_hosts";
        assert_script_run("touch $filename") unless (-f $filename);
        assert_script_run("ssh-keyscan localhost 127.0.0.1 ::1 | tee -a $filename");
        assert_script_run 'cp ~/.ssh/{id_rsa.pub,authorized_keys}';
    }

    assert_script_run("rsync -avzr /tmp/rsync_test_folder_a/ root\@localhost:/tmp/rsync_test_folder_b");
    assert_script_run('time sync');

    # keep the md5 hash value of the synced file and folder
    my $md5_synced_file = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_file');
    my $md5_synced_sh = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_sh.sh');
    my $md5_synced_tar = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_tar.tar');

    # compare the hash values
    die("MD5 hash value of the synced text file is different from the initial one") unless ($md5_initial_file == $md5_synced_file);
    die("MD5 hash value of the synced sh file is different from the initial one") unless ($md5_initial_sh == $md5_synced_sh);
    die("MD5 hash value of the synced tar file is different from the initial one") unless ($md5_initial_tar == $md5_synced_tar);
}

sub post_run_hook {
    assert_script_run('rm -rf /tmp/rsync_test_folder_a');
    assert_script_run('rm -rf /tmp/rsync_test_folder_b');

    if (is_opensuse) {
        systemctl 'restart sshd';
    }
}

1;
