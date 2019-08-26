# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Mount an iso file using autofs/automount
# - If SLE15+, installs autofs mkisofs
# - Creates a temporary directory, /mnt/test_autofs_local
# - Inside temporary directory, creates a README file, with 4024 bytes.
# - Creates a /tmp/test-iso.iso with contents of temporary directory using
# mkisofs
# - Checks iso created using "ls -lh"
# - Calls check_autofs_service (start/stop/restart/status of autofs)
# - Calls setup_autofs_server (configure autofs config files)
# - Restart autofs
# - Runs ls /mnt/test_autofs_local/iso
# - Checks output of mount | grep -e /tmp/test-iso.iso contains
# "/tmp/test-iso.iso", otherwise, abort
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_jeos);
use autofs_utils qw(setup_autofs_server check_autofs_service);
use utils qw(systemctl zypper_call);

sub run {
    select_console 'root-console';
    # mkisofs is not distributed in JeOS based on sle12
    my $mk_iso_tool = (is_jeos and is_sle('<15')) ? 'genisoimage' : 'mkisofs';
    zypper_call("in autofs $mk_iso_tool") if (is_sle('15+') or is_jeos);
    my $autofs_conf_file       = '/etc/auto.master';
    my $autofs_map_file        = '/etc/auto.master.d/autofs_regression_test.autofs';
    my $test_conf_file         = '/etc/auto.iso';
    my $test_mount_dir         = '/mnt/test_autofs_local';
    my $file_to_mount          = '/tmp/test-iso.iso';
    my $test_conf_file_content = "echo  iso     -fstype=auto,ro         :$file_to_mount > $test_conf_file";
    assert_script_run("mkdir -p $test_mount_dir");
    assert_script_run("dd if=/dev/urandom of=$test_mount_dir/README bs=4024 count=1");
    assert_script_run("$mk_iso_tool -o $file_to_mount $test_mount_dir");
    assert_script_run("ls -lh $file_to_mount");
    check_autofs_service();
    assert_script_run("test -f $autofs_conf_file");
    setup_autofs_server(autofs_conf_file => $autofs_conf_file, autofs_map_file => $autofs_map_file, test_conf_file => $test_conf_file, test_conf_file_content => $test_conf_file_content, test_mount_dir => $test_mount_dir);
    systemctl 'restart autofs';
    assert_script_run("ls $test_mount_dir/iso");
    my $mount_output_triggered = script_output("mount | grep -e $file_to_mount");
    die "Something went wrong, target is already mounted" unless $mount_output_triggered =~ /$file_to_mount/;
}

1;
