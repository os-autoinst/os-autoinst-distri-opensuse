# SUSE's openQA tests
#
# Copyright 2019-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: autofs nfs-client
# Summary: It waits until a nfs server is ready and mounts a dir from that one.
#          It also mounts another dir to check nfsidmap functionality.
# - Calls check_autofs_service (start/stop/restart/status autofs)
# - Calls setup_autofs_server (setup autofs config files)
# - Restarts autofs daemon
# - Checks output of "systemctl --no-pager status autofs" for "active/Active"
# - Run "rpm -q nfsidmap"
# - Run "nfsidmap -c || true" to clear keyring
# - Run mkdir -p /mnt/test_nfsidmap
# - Call barrier_wait for 'AUTOFS_SUITE_READY'
# - Run ls /mnt/test/test
# - Run mount | grep -e /mnt/test/test
# - Check the contents of file /mnt/test/test/file.txt for "It worked"
# - Run "mount -t nfs4 10.0.2.101:/home/tux /mnt/test_nfsidmap
# - Run "ls /mnt/test/test"
# - Run "ls -l /mnt/test_nfsidmap/tux.txt and check output for
# m/nobody.*users.*tux.txt/ (file owner nobody)
# - Run "cat /mnt/test_nfsidmap/tux.txt" and check file content for "Hi tux"
# - Run "umount /mnt/test_nfsidmap/"
# - Run "useradd -m tux"
# - Run "nfsidmap -c || true"
# - Run "mount -t nfs4 $10.0.2.101:/home/tux /mnt/test_nfsidmap"
# - Run "ls -l /mnt/test_nfsidmap/tux.txt", checks output for
# m/tux.*users.*tux.txt/ (user tux)
# - Run "cat /mnt/test_nfsidmap/tux.txt", check output for "Hi tux"
# - Run "umount /mnt/test_nfsidmap/"
# - Call barrier_wait for 'AUTOFS_FINISHED'
# Maintainer: Antonio Caristia <acaristia@suse.com> (autofs)
# Maintainer: Timo Jyrinki <tjyrinki@suse.com> (nfsidmap)

use base 'consoletest';
use testapi;
use lockapi;
use autofs_utils qw(setup_autofs_server check_autofs_service);
use utils qw(systemctl script_retry);
use version_utils 'is_opensuse';
use strict;
use warnings;

sub run {
    # autofs client needs mutex_wait
    mutex_wait 'barrier_setup_done';

    select_console "root-console";
    my $nfs_server = "10.0.2.101";
    my $remote_mount = "/tmp/nfs/server";
    my $remote_mount_nfsidmap = "/home/tux";
    my $autofs_conf_file = '/etc/auto.master';
    my $autofs_map_file = '/etc/auto.master.d/autofs_regression_test.autofs';
    my $test_conf_file = '/etc/auto.share';
    my $test_mount_dir = '/mnt/test';
    my $test_mount_dir_nfsidmap = '/mnt/test_nfsidmap';
    my $test_conf_file_content = "test -ro $nfs_server:$remote_mount";

    # autofs
    check_autofs_service();
    setup_autofs_server(autofs_conf_file => $autofs_conf_file, autofs_map_file => $autofs_map_file, test_conf_file => $test_conf_file, test_conf_file_content => $test_conf_file_content, test_mount_dir => $test_mount_dir);
    systemctl 'restart autofs';
    validate_script_output("systemctl --no-pager status autofs", sub { m/Active:\s*active/ }, 180);

    # nfsidmap
    is_opensuse ? assert_script_run("rpm -q libnfsidmap1") : assert_script_run("rpm -q nfsidmap");
    # Allow failing, it's to clear the keyring if one exists
    assert_script_run("nfsidmap -c || true");
    assert_script_run("mkdir -p $test_mount_dir_nfsidmap");

    barrier_wait 'AUTOFS_SUITE_READY';

    # autofs
    # Due to poo#131291, we can add retries on client to sync the data from server
    script_retry("ls $test_mount_dir/test", delay => 10, retry => 3);
    assert_script_run("mount | grep -e $test_mount_dir/test");
    validate_script_output("cat $test_mount_dir/test/file.txt", sub { m/It worked/ }, 200);

    # nfsidmap
    assert_script_run("mount -t nfs4 $nfs_server:$remote_mount_nfsidmap $test_mount_dir_nfsidmap");
    assert_script_run("ls $test_mount_dir/test");
    # Without existing user the nfsidmap should map the owner to 'nobody'
    validate_script_output("ls -l $test_mount_dir_nfsidmap/tux.txt", sub { m/nobody.*users.*tux.txt/ });
    validate_script_output("cat $test_mount_dir_nfsidmap/tux.txt", sub { m/Hi tux/ });
    assert_script_run("umount $test_mount_dir_nfsidmap");
    assert_script_run("useradd -m tux");
    assert_script_run("nfsidmap -c || true");
    assert_script_run("mount -t nfs4 $nfs_server:$remote_mount_nfsidmap $test_mount_dir_nfsidmap");
    # Now 'tux' should be shown instead
    validate_script_output("ls -l $test_mount_dir_nfsidmap/tux.txt", sub { m/tux.*users.*tux.txt/ });
    validate_script_output("cat $test_mount_dir_nfsidmap/tux.txt", sub { m/Hi tux/ });
    assert_script_run("umount $test_mount_dir_nfsidmap");
    barrier_wait 'AUTOFS_FINISHED';
}

1;
