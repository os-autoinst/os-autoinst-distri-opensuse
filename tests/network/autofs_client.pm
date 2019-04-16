# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: It waits until a nfs server is ready and mounts a dir from that one
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base 'consoletest';
use testapi;
use lockapi;
use autofs_utils qw(setup_autofs_server check_autofs_service);
use utils qw(systemctl);
use strict;
use warnings;

sub run {
    select_console "root-console";
    my $nfs_server             = "10.0.2.101";
    my $remote_mount           = "/tmp/nfs/server";
    my $autofs_conf_file       = '/etc/auto.master';
    my $autofs_map_file        = '/etc/auto.master.d/autofs_regression_test.autofs';
    my $test_conf_file         = '/etc/auto.share';
    my $test_mount_dir         = '/mnt/test';
    my $test_conf_file_content = "echo  test    -ro,no_subtree_check              $nfs_server:$remote_mount > $test_conf_file";
    check_autofs_service();
    setup_autofs_server(autofs_conf_file => $autofs_conf_file, autofs_map_file => $autofs_map_file, test_conf_file => $test_conf_file, test_conf_file_content => $test_conf_file_content, test_mount_dir => $test_mount_dir);
    systemctl 'restart autofs';
    validate_script_output("systemctl --no-pager status autofs", sub { m/Active:\s*active/ }, 180);
    barrier_wait 'AUTOFS_SUITE_READY';
    assert_script_run("ls $test_mount_dir/test");
    assert_script_run("mount | grep -e $test_mount_dir/test");
    validate_script_output("cat $test_mount_dir/test/file.txt", sub { m/It worked/ }, 200);
    barrier_wait 'AUTOFS_FINISHED';
}

1;
