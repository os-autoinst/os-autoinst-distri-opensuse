# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: parted e2fsprogs
# Summary: Copy the installation ISO to an external drive
# Maintainer: Joachim Rauch <jrauch@suse.com>
# Tags: boo#1040749

use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use utils 'get_root_console_tty';

sub run {
    my ($self) = @_;

    select_console 'root-console';

    # choose unpartioned disk and set <$disk> shell variable
    $self->set_playground_disk;
    my $disk = get_var('PLAYGROUNDDISK');
    #partition HDD2
    assert_script_run "echo Disk: $disk";
    assert_script_run "parted -s $disk mklabel gpt", 240;
    assert_script_run "parted -s -a opt $disk mkpart primary ext4 0% 50%", 240;
    my $partition = $disk . "1";
    assert_script_run "mkfs.ext4 $partition", 240;

    #mount HDD2
    assert_script_run "mount $partition /mnt";

    #copy iso from DVD to HDD2
    assert_script_run 'dd if=/dev/dvd of=/mnt/install.iso', 3000;

    #check if copy worked
    assert_script_run '[[ $(md5sum /dev/dvd | awk \'{print $1}\') == $(md5sum /mnt/install.iso | awk \'{print $1}\') ]]';
}

sub post_run_hook {
    #prepare environment for next test
    enter_cmd "logout";
    my $tty = get_root_console_tty;
    assert_screen "tty$tty-selected";
    select_console "x11";
}

1;
