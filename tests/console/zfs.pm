# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: zfs util-linux
# Summary: Tests the functionality of the zfs filesystem
# - Install zfs and load the module
# - Format three disks and assemble a raidz ('tank')
# - Format a single disk ('dozer')
# - Test disk failure in raidz
# - Test snapshot handling (create, delete, rename, rollback)
# - Test .zfs/snapshot for correct snapshots
# - Test snapshot transfer (tank->dozer)
# - Test if the module and filesystems survive a reboot
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use power_action_utils 'power_action';

sub get_repository() {
    if (is_tumbleweed) {
        return 'https://download.opensuse.org/repositories/filesystems/openSUSE_Tumbleweed/filesystems.repo';
    } elsif (is_leap("=15.3")) {
        return 'https://download.opensuse.org/repositories/filesystems/openSUSE_Leap_15.3/filesystems.repo';
    } elsif (is_leap("=15.2")) {
        return 'https://download.opensuse.org/repositories/filesystems/openSUSE_Leap_15.2/filesystems.repo';
    } elsif (is_leap("=15.1")) {
        return 'https://download.opensuse.org/repositories/filesystems/openSUSE_Leap_15.1/filesystems.repo';
    } elsif (is_sle("=15.3")) {
        return 'https://download.opensuse.org/repositories/filesystems/SLE_15_SP3/filesystems.repo';
    } elsif (is_sle("=15.2")) {
        return 'https://download.opensuse.org/repositories/filesystems/SLE_15_SP2/filesystems.repo';
    } elsif (is_sle("=15.1")) {
        return 'https://download.opensuse.org/repositories/filesystems/SLE_15_SP1/filesystems.repo';
    } elsif (is_sle("=12.5")) {
        return 'https://download.opensuse.org/repositories/filesystems/SLE_12_SP5/filesystems.repo';
    } elsif (is_sle("=12.4")) {
        return 'https://download.opensuse.org/repositories/filesystems/SLE_12_SP4/filesystems.repo';
    } else {
        die "Unsupported version";
    }
}

# Check if the repository is available and enabled
sub check_available {
    my $repo = shift;
    return script_run("curl -f '$repo' | grep 'enabled=1'") == 0;
}

sub install_zfs {
    my $repo = get_repository();
    if (!check_available($repo)) {
        my $msg = "Sorry, zfs repository is not (yet) available for this distribution";
        record_soft_failure($msg);
        return 0;
    }
    # TODO: Replace -G (--no-gpgcheck) with something more sane
    zypper_call("addrepo -fG $repo");
    zypper_call('refresh');
    zypper_call('install zfs');
    return 1;
}

sub prepare_disks {
    assert_script_run('fallocate -l 1GB /var/tmp/tank_a.img');
    assert_script_run('fallocate -l 1GB /var/tmp/tank_b.img');
    assert_script_run('fallocate -l 1GB /var/tmp/tank_c.img');
    assert_script_run('fallocate -l 1GB /var/tmp/tank_a2.img');
    assert_script_run('fallocate -l 1GB /var/tmp/dozer.img');
}

sub clear_disk {
    my $disk = shift;
    assert_script_run("dd if=/dev/zero of=$disk bs=1G count=1");
}

sub corrupt_disk {
    my $disk = shift;
    # Note dd from /dev/urandom and random is limited to ~30MB per read
    assert_script_run("dd if=/dev/urandom of=$disk bs=10M count=100");
}

sub cleanup {
    script_run('cd');
    script_run('if zpool list | grep tank ; then zpool destroy tank; fi');
    script_run('if zpool list | grep dozer ; then zpool destroy dozer; fi');
    script_run('rm -f /var/tmp/tank_{a,b,c}.img /var/tmp/dozer.img');
}

sub scrub {
    my $pool = shift;
    assert_script_run("zpool scrub $pool");
    # Wait for scrub to finish
    script_retry("zpool status $pool | grep scan | grep -v 'in progress'", delay => 1, retry => 30);
}

sub reboot {
    my ($self) = @_;
    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 300);
    select_console 'root-console';
}

sub run {
    # Preparation
    my $self = shift;
    $self->select_serial_terminal;
    select_console 'root-console';
    return unless (install_zfs());    # Possible softfailure if module is not yet available (e.g. new Leap version)
    assert_script_run('modprobe zfs');
    prepare_disks();

    ## Prepare test pools
    # Create zfs test pools
    assert_script_run('zpool create tank raidz /var/tmp/tank_{a,b,c}.img -o ashift=13');
    assert_script_run('zpool list | grep tank');
    assert_script_run('zpool create dozer /var/tmp/dozer.img -o ashift=12');
    assert_script_run('zpool list | grep dozer');
    assert_script_run('cd /tank/; ls');
    # Put data in tank
    assert_script_run('curl -v -o /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv ' . data_url('Big_Buck_Bunny_8_seconds_bird_clip.ogv'));
    assert_script_run('md5sum Big_Buck_Bunny_8_seconds_bird_clip.ogv > /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    assert_script_run('md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    scrub('tank');
    assert_script_run('zpool status tank | grep state | grep ONLINE');
    script_run('zpool status tank');

    ## Test raidz capability by corruping a disk
    corrupt_disk('/var/tmp/tank_a.img');
    assert_script_run('md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    scrub('tank');
    assert_script_run("zpool status tank | grep scan | grep 'scrub repaired'");
    assert_script_run('md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    script_run('zpool status tank');
    assert_script_run('zpool status tank | grep "corrupted data"');
    # Replace disk
    assert_script_run('zpool offline tank /var/tmp/tank_a.img');
    clear_disk('/var/tmp/tank_a.img');
    assert_script_run('zpool replace tank /var/tmp/tank_a.img');
    scrub('tank');
    assert_script_run('zpool status tank | grep state | grep ONLINE');
    # Display status for debugging purposes
    script_run('zpool status tank');

    ## Test Snapshots
    assert_script_run('zfs snapshot tank@initial');
    assert_script_run('zfs list -t snapshot | grep "tank@initial"');
    assert_script_run('curl -v -o /tank/test_unzip.zip ' . data_url('console/test_unzip.zip'));
    assert_script_run('rm /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    # Create second snapshot with other data
    assert_script_run('zfs snapshot tank@second');
    assert_script_run('zfs snapshot tank@third');
    assert_script_run('zfs list -t snapshot | grep "tank@second"');
    assert_script_run('zfs list -t snapshot | grep "tank@third"');
    # Mount snapshots
    assert_script_run('mkdir -p /mnt/tank/{initial,second}');
    # Note: zfs snapshots are mounted ro by default
    assert_script_run('mount -t zfs tank@initial /mnt/tank/initial');
    assert_script_run('! touch /mnt/tank/initial/no_touch');    # test if zfs snapshots are mounted ro by default
    assert_script_run('zfs clone -o mountpoint=/mnt/tank/second tank@second tank/2nd_second');
    assert_script_run('stat /mnt/tank/initial/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('cd /mnt/tank/initial/; md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    assert_script_run('! stat /mnt/tank/initial/test_unzip.zip');
    assert_script_run('! stat /mnt/tank/second/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('stat /mnt/tank/second/test_unzip.zip');
    # Check also if snapshots are in the .zfs/snapshot directory
    assert_script_run('cd');
    assert_script_run('umount /mnt/tank/{initial,second}');
    assert_script_run('ls -al /tank/.zfs/snapshot/');
    assert_script_run('ls -al /tank/.zfs/snapshot/initial/');
    assert_script_run('stat /tank/.zfs/snapshot/initial/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('! stat /tank/.zfs/snapshot/initial/test_unzip.zip');
    assert_script_run('stat /tank/.zfs/snapshot/second/test_unzip.zip');
    assert_script_run('! stat /tank/.zfs/snapshot/second/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    # Test holding snapshots and delete snapshots
    assert_script_run('zfs hold keep tank@initial');
    assert_script_run('zfs hold keep tank@second');
    assert_script_run('! zfs destroy tank@initial');
    assert_script_run('! zfs destroy tank@second');
    assert_script_run('! zfs destroy tank@2nd_second');
    assert_script_run('zfs release -r keep tank@second');
    assert_script_run('zfs destroy -R tank@second');
    script_retry('zfs list -t snapshot | grep -v "tank@second"', delay => 1, retry => 30);
    assert_script_run('zfs list -t snapshot | grep "tank@initial"');
    assert_script_run('zfs list -t snapshot | grep "tank@third"');
    # Rename snapshot
    assert_script_run('zfs rename tank@initial tank@today');
    assert_script_run('zfs list -t snapshot | grep "tank@today"');
    assert_script_run('! zfs list -t snapshot | grep "tank@initial"');
    # Send snapshot to second zfs pool
    assert_script_run('zfs send "tank@today" | zfs recv -F "dozer@today"');
    script_run('zfs list -t snapshot | grep "dozer@today"');
    ## Test rollback
    assert_script_run('zfs rollback -r tank@today');
    # Note: Rollback also deletes more recent snaptshots (so snapshot 'third' must be gone)
    script_run('! zfs list -t snapshot | grep third');
    assert_script_run('stat /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('cd /tank; md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    assert_script_run('! stat /tank/test_unzip.zip');
    # Check transferred snapshot
    assert_script_run('mkdir -p /mnt/dozer/today');
    assert_script_run('mount -t zfs dozer@today /mnt/dozer/today');
    assert_script_run('stat /mnt/dozer/today/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('cd /mnt/dozer/today; md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    assert_script_run('! stat /mnt/dozer/today/test_unzip.zip');
    assert_script_run('cd');
    assert_script_run('umount /mnt/dozer/today');
    # Prepare new snapshot for reboot
    assert_script_run('mv /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv /tank/BBB_8_seconds_bird_clip.ogv');
    assert_script_run('touch /tank/snapshot_3');
    assert_script_run('zfs snapshot tank@third');
    assert_script_run('mv /tank/BBB_8_seconds_bird_clip.ogv /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv');

    ## Check if zfs survives a reboot
    assert_script_run("echo zfs > /etc/modules-load.d//90-zfs.conf");
    assert_script_run("chmod 0644 /etc/modules-load.d//90-zfs.conf");
    reboot($self);
    assert_script_run("lsmod | grep zfs");
    assert_script_run("systemctl status zfs.target | grep 'active'");
    assert_script_run("systemctl status zfs-share | grep 'active'");
    # Since zpool by default only searches for disks but not files, we need to point it to the disk files manually
    assert_script_run("zpool import -d /var/tmp/tank_a.img -d /var/tmp/tank_b.img -d /var/tmp/tank_c.img tank");
    assert_script_run('zpool list | grep "tank"');
    assert_script_run("zpool import -d /var/tmp/dozer.img dozer");
    assert_script_run('zpool list | grep "dozer"');
    assert_script_run('stat /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('cd /tank; md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    assert_script_run('! stat /tank/test_unzip.zip');
    # Test snapshot after reboot
    assert_script_run('zfs rollback -r tank@third');
    assert_script_run('stat /tank/BBB_8_seconds_bird_clip.ogv');
    assert_script_run('stat /tank/snapshot_3');
    assert_script_run('cd /tank');
    assert_script_run('mv BBB_8_seconds_bird_clip.ogv Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    assert_script_run('md5sum -c /var/tmp/Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5sum');
    ## Cleanup tests
    # Test zfs umount
    assert_script_run('cd');
    assert_script_run('zfs umount tank');
    assert_script_run('! stat /tank/Big_Buck_Bunny_8_seconds_bird_clip.ogv');
    # Celebrate successful test run :-)
    script_run("echo -e 'Congarts! zfs test completed sucessfully\n.~~~~.\ni====i_\n|cccc|_)\n|cccc|   hjw\n -==-'");
}

sub post_fail_hook {
    my ($self) = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    cleanup();
}

1;
