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

use base "consoletest";
use testapi;
use strict;
use utils 'service_action';

sub run() {
    select_console 'root-console';

    my @snapper_runs = 'snapper';
    push @snapper_runs, 'snapper --no-dbus' if get_var('SNAPPER_NODBUS');
    my $mnt_thin          = '/mnt/thin';
    my $mnt_thin_snapshot = $mnt_thin . '-snapshot';

    foreach my $snapper (@snapper_runs) {
        service_action('dbus', {type => ['socket', 'service'], action => ['stop', 'mask']}) if ($snapper =~ /dbus/);

        # Create partition on /dev/vbd
        assert_script_run 'echo -e "g\nn\n\n\n\nt\n8e\np\nw" | fdisk /dev/vdb';
        assert_script_run 'lsblk';

        # Create a volume group named 'test'
        assert_script_run 'vgcreate test /dev/vdb1';
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
        assert_script_run 'echo -e "g\np\nw" | fdisk /dev/vdb';
        assert_script_run 'lsblk';

        service_action('dbus', {type => ['socket', 'service'], action => ['unmask', 'start']}) if ($snapper =~ /dbus/);
    }
}

1;
# vim: set sw=4 et:
