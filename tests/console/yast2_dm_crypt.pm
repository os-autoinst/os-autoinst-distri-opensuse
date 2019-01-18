# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1525213 - FIPS: dm-crypt

# Summary: Add dm crypt test for fips
# Maintainer: mgriessmeier <mgriessmeier@suse.de>

use base "console_yasttest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_desktop_installed';

sub run {
    my ($self)        = @_;
    my $loop_filename = 'loopfile';
    my $mount_point   = '/mnt/test';
    my $test_filename = 'file_in_crypted_volume';

    select_console 'root-console';
    script_run("yast2 disk; echo yast2-disk-status-\$? > /dev/$serialdev", 0);

    assert_screen "yast2-disk-warning";
    send_key "alt-y";    # continue despite the warning

    assert_screen "yast2-expert-partitioner";
    send_key "alt-s";    # select system view
    send_key_until_needlematch "yast2-disk-cryptfiles", "down", 10;
    send_key "ret";      # show Crypt Files tab

    # add crypt file
    send_key "alt-a";
    assert_screen "yast2-add-crypt-file";
    send_key "alt-p";    # focus on path name of loop file
    type_string "/root/$loop_filename";
    send_key "alt-c";    # toggle create loop file
    send_key "alt-n";

    # format and mount options
    assert_screen "yast2-cryptfile-options";
    send_key "alt-m";    # focus on mount point
    type_string $mount_point;
    send_key "alt-n";

    # set password for crypt file
    assert_screen "yast2-cryptfile-password";
    send_key "alt-t";
    type_password;
    send_key "alt-v";
    type_password;
    send_key "alt-f";    # finish adding crypt file

    # create newly added crypt file
    assert_screen "yast2-cryptfile-added";
    send_key "alt-n";
    assert_screen "yast2-cryptfile-summary";
    send_key "alt-f";
    # a package need to be installed before cryptfile
    # creation on Tumbleweed, give more time to wait
    assert_screen "yast2-cryptfile-creation", 180;

    wait_serial('yast2-disk-status-0') || die "'yast2 disk' didn't finish";

    # check if crypt file volume is mounted automatically
    assert_script_run "mount | grep $mount_point";
    assert_script_run "touch $mount_point/$test_filename";

    # reboot system with crypt file volume
    set_var("ENCRYPT", 1);
    script_run("reboot", 0);
    # on s390 svirt we need to unlock encryption here
    unlock_if_encrypted if get_var('S390_ZKVM');
    $self->wait_boot(textmode => !is_desktop_installed, bootloader_time => 300);

    # check the crypt mount volume after reboot
    select_console 'root-console';
    assert_script_run "mount | grep $mount_point";
    assert_script_run "ls $mount_point/$test_filename";

    # delete crypt file volume and clean up
    script_run "umount $mount_point";
    script_run "rm /root/$loop_filename";
    script_run "sed -i '\$ d' /etc/fstab";
    # make sure that the line of crypt file volume was deleted
    assert_script_run "! cat /etc/fstab | grep $mount_point";
    set_var("ENCRYPT", 0);
}

1;
