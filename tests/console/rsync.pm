# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module creates files that are synced afterwards using rsync.
# Maintainer: Ciprian Cret <ccret@suse.com>


use base "opensusebasetest";
use strict;
use testapi;
use utils;
use version_utils qw(is_opensuse is_sle is_jeos);

sub run {
    # try to install rsync if the test does not run on JeOS
    if (!is_jeos) {
        select_console 'root-console';
        zypper_call('-t in rsync', dumb_term => 1);
    }

    # create the folders and files that will be synced
    select_console('root-console');
    assert_script_run('mkdir /tmp/rsync_test_folder_a');
    assert_script_run('mkdir /tmp/rsync_test_folder_b');
    assert_script_run('echo rsync_test > /tmp/rsync_test_folder_a/rsync_test_file');
    assert_script_run("echo '#!/bin/sh\\necho Hello World' > /tmp/rsync_test_folder_a/rsync_test_sh.sh");
    assert_script_run('tar -cvf /tmp/rsync_test_folder_a/rsync_test_tar.tar /tmp/rsync_test_folder_a/rsync_test_file');

    my $md5_initial_file = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_file');
    my $md5_initial_sh   = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_sh.sh');
    my $md5_initial_tar  = script_output('md5sum /tmp/rsync_test_folder_a/rsync_test_tar.tar');

    # in case localhost is already inside known_hosts
    if (script_run('! test -e ~/.ssh')) {
        assert_script_run('ssh-keygen -R localhost');
    }

    if (is_opensuse) {
        my $output = script_output('cat /etc/ssh/sshd_config | grep "#PermitRootLogin"');
        if ($output =~ 'prohibit-password') {
            clear_console;
            assert_script_run("sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config");
            assert_script_run("systemctl restart sshd");
        }
    }

    type_string("rsync -avzr /tmp/rsync_test_folder_a/ root\@localhost:/tmp/rsync_test_folder_b; echo \$\? > /tmp/rsync_return_code.txt\n");

    if (is_jeos || is_sle) {
        assert_screen('remote-ssh-login');
    }
    elsif (is_opensuse) {
        assert_screen('accept-ssh-host-key');
    }
    type_string('yes');
    send_key('ret');
    assert_screen('password-prompt');
    type_password;
    send_key('ret');
    assert_screen('rsync');
    assert_script_run('$(exit $(cat /tmp/rsync_return_code.txt))');

    # keep the md5 hash value of the synced file and folder
    my $md5_synced_file = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_file');
    my $md5_synced_sh   = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_sh.sh');
    my $md5_synced_tar  = script_output('md5sum /tmp/rsync_test_folder_b/rsync_test_tar.tar');

    # compare the hash values
    die("MD5 hash value of the synced text file is different from the initial one") unless ($md5_initial_file == $md5_synced_file);
    die("MD5 hash value of the synced sh file is different from the initial one")   unless ($md5_initial_sh == $md5_synced_sh);
    die("MD5 hash value of the synced tar file is different from the initial one")  unless ($md5_initial_tar == $md5_synced_tar);
}

sub post_run_hook {
    assert_script_run('rm -rf /tmp/rsync_test_folder_a');
    assert_script_run('rm -rf /tmp/rsync_test_folder_b');
    assert_script_run('rm /tmp/rsync_return_code.txt');

    if (is_opensuse) {
        my $output = script_output('cat /etc/ssh/sshd_config | grep PermitRootLogin');
        if ($output =~ 'yes') {
            assert_script_run("sed -i 's/PermitRootLogin yes/#PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config");
            assert_script_run("systemctl restart sshd");
        }
    }
}

1;
