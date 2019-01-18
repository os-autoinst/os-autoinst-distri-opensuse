# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Copy the installation ISO to an external drive
# Maintainer: Joachim Rauch <jrauch@suse.com>
# Tags: boo#1040749

use base 'btrfs_test';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;

    select_console 'root-console';

    # choose unpartioned disk and set <$disk> shell variable
    $self->set_playground_disk;
    my $disk = get_var('PLAYGROUNDDISK');
    #partition HDD2
    assert_script_run "echo Disk: $disk";
    assert_script_run "parted $disk mklabel gpt",                       240;
    assert_script_run "parted -a opt $disk mkpart primary ext4 0% 50%", 240;
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
    type_string "logout\n";
    assert_screen "text-login";
    select_console "x11";
}

1;
