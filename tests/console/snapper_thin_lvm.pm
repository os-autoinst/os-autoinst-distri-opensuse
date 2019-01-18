# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test snapper on thin-provisioned LVM
# poo#15944 FATE#321049
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'btrfs_test';
use testapi;
use strict;
use warnings;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my @snapper_runs = 'snapper';
    push @snapper_runs, 'snapper --no-dbus' if get_var('SNAPPER_NODBUS');
    my $mnt_thin          = '/mnt/thin';
    my $mnt_thin_snapshot = $mnt_thin . '-snapshot';

    zypper_call 'in lvm2';
    foreach my $snapper (@snapper_runs) {
        $self->snapper_nodbus_setup if $snapper =~ /dbus/;

        $self->set_playground_disk;
        my $disk = get_required_var('PLAYGROUNDDISK');

        # Create partition on unpartitioned
        assert_script_run 'echo -e "g\nn\n\n\n\nt\n8e\np\nw" | fdisk ' . $disk;
        assert_script_run 'lsblk';

        # Create a volume group named 'test'
        assert_script_run "vgcreate test ${disk}1";
        # Follow guide at https://lizards.opensuse.org/2012/07/25/snapper-lvm/
        assert_script_run 'lvcreate --thin test/pool --size 3G';
        assert_script_run 'lvcreate --thin test/pool --virtualsize 5G --name thin';
        assert_script_run 'mkfs.ext4 /dev/test/thin';
        assert_script_run "mkdir $mnt_thin";
        assert_script_run "mount /dev/test/thin $mnt_thin";
        # Do not use --size or -L and thin snapshot will be created
        assert_script_run 'lvcreate --snapshot --name thin-snap1 /dev/test/thin';
        assert_script_run "mkdir $mnt_thin_snapshot";
        assert_script_run 'lvchange -ay -K test/thin-snap1';
        assert_script_run "mount /dev/test/thin-snap1 $mnt_thin_snapshot";
        assert_script_run 'lvs';
        # Create snapper config
        assert_script_run "$snapper -c thin create-config --fstype=\"lvm(ext4)\" $mnt_thin";
        assert_script_run "$snapper -c thin list-configs | grep '^thin '";

        # Touch /mnt/thin/lenny file after 'pre' snapshot and before 'post' snapshot
        assert_script_run "N=\"\$($snapper -c thin create --command \"touch $mnt_thin/lenny\" -p)\"";
        # Verify /mnt/thin/lenny exists in 'post' snapshot
        assert_script_run "$snapper -c thin status \$N | grep \"^+..... $mnt_thin/lenny\"";

        # Cleanup
        assert_script_run "$snapper -c thin delete-config";
        assert_script_run "$snapper -c thin list-configs | grep -v '^thin '";
        assert_script_run "umount $mnt_thin_snapshot";
        assert_script_run "umount $mnt_thin";
        assert_script_run "rm -rf $mnt_thin_snapshot $mnt_thin";
        assert_script_run 'vgremove -f test';
        $self->cleanup_partition_table;
        assert_script_run 'lsblk';

        $self->snapper_nodbus_restore if $snapper =~ /dbus/;
    }
}

1;

