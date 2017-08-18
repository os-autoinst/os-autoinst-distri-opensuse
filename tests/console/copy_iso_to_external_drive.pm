# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Copy the installation ISO to an external drive
#    test for bug boo#1040749
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

use base 'btrfs_test';
use strict;
use testapi;

sub run() {
    my ($self) = @_;

    #select_console 'user-console';
    select_console 'root-console';

    type_string "mount | tee /dev/$serialdev\n";

    # choose unpartioned disk and set <$disk> shell variable
    $self->set_unpartitioned_disk_in_bash;

    #partition HDD2
    assert_script_run "parted \$disk mklabel gpt";
    assert_script_run "parted -a opt \$disk mkpart primary ext4 0% 100%";
    assert_script_run "mkfs.ext4 \$disk'1'";

    #mount HDD2
    assert_script_run "mount \$disk'1' /mnt";

    #copy iso from DVD to HDD2
    assert_script_run "dd if=/dev/dvd of=/mnt/install.iso" , 3000;

    #check if copy worked
    assert_script_run "` [[ -s /mnt/install.iso  ]]`";
    select_console "x11";
}

1;
# vim: set sw=4 et:
