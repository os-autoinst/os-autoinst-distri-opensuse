# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: it covers basic lvm commands
# pvcreate vgcreate lvcreate
# pvdisplay vgdisplay lvdisplay
# vgextend lvextend
# pvmove vgreduce
# pvremove vgremove lvremove
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base "consoletest";
use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use version_utils;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    select_console 'root-console';
    $self->set_playground_disk;
    my $disk = get_required_var('PLAYGROUNDDISK');
    zypper_call 'in lvm2';
    zypper_call 'in xfsprogs';
    # Create 3  partitions
    assert_script_run 'echo -e "g\nn\n\n\n+1G\nt\n8e\nn\n\n\n+1G\nt\n2\n8e\nn\n\n\n\nt\n\n8e\np\nw" | fdisk ' . $disk;
    assert_script_run("lsblk");
    # Create pv vg lv
    validate_script_output("pvcreate ${disk}1",             sub { m/successfully created/ }, 180);
    validate_script_output("pvdisplay",                     sub { m/\/dev\/vdb1/ },          180);
    validate_script_output("vgcreate test ${disk}1",        sub { m/successfully created/ }, 180);
    validate_script_output("vgdisplay test",                sub { m/test/ },                 180);
    validate_script_output("lvcreate -n one -L 1020M test", sub { m/created/ },              180);
    validate_script_output("lvdisplay",                     sub { m/one/ },                  180);
    # create a fs
    assert_script_run("mkfs -t xfs /dev/test/one");
    assert_script_run("mkdir /mnt/test_lvm");
    assert_script_run("mount /dev/test/one /mnt/test_lvm");
    assert_script_run("echo test > /mnt/test_lvm/test");
    assert_script_run("cat /mnt/test_lvm/test|grep test");
    assert_script_run("umount /mnt/test_lvm");
    #extend test volume group
    validate_script_output("pvcreate ${disk}2",      sub { m/successfully created/ },  180);
    validate_script_output("pvdisplay",              sub { m/\/dev\/vdb2/ },           180);
    validate_script_output("vgextend test ${disk}2", sub { m/successfully extended/ }, 180);
    # extend one logical volume with the new space
    validate_script_output("lvextend -L +1020M /dev/test/one", sub { m/successfully resized/ }, 180);
    assert_script_run("mount /dev/test/one /mnt/test_lvm");
    assert_script_run("cat /mnt/test_lvm/test|grep test");
    # extend the filesystem
    validate_script_output("xfs_growfs /mnt/test_lvm", sub { m/data blocks changed/ }, 180);
    validate_script_output("df -h /mnt/test_lvm", sub { m/test/ }, 180);
    assert_script_run("cat /mnt/test_lvm/test|grep test");
    # move data from the original extend to the new one
    validate_script_output("pvcreate ${disk}3",      sub { m/successfully created/ },  180);
    validate_script_output("vgextend test ${disk}3", sub { m/successfully extended/ }, 180);
    assert_script_run("pvmove ${disk}1 ${disk}3");
    # after moving data, remove the old extend with no data
    validate_script_output("vgreduce test ${disk}1", sub { m/Removed/ }, 180);
    # check the data just to be sure
    assert_script_run("cat /mnt/test_lvm/test|grep test");
    # remove all
    assert_script_run("umount /mnt/test_lvm");
    validate_script_output("lvremove -y /dev/test/one", sub { m/successfully removed/ }, 180);
    assert_script_run("lvdisplay");
    validate_script_output("vgremove -y test", sub { m/successfully removed/ }, 180);
    assert_script_run("vgdisplay");
    validate_script_output("pvremove -y ${disk}1 ${disk}2 ${disk}3", sub { m/successfully wiped/ }, 180);
    assert_script_run("pvdisplay");

}

1;
