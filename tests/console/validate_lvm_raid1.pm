# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: RAID1 on LVM partition validation
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.com>

use strict;
use warnings;
use base "y2_module_consoletest";
use testapi;
use utils;
use Test::Assert ':all';
use scheduler 'get_test_data';
use version_utils "is_sle";
use power_action_utils 'power_action';

sub run {
    my $self = shift;

    select_console 'root-console';

    my $config = get_test_data();
    $config->{expected_num_devs} = scalar @{$config->{disks}};
    # actual_num_devs is used to get the number of the disks in raid
    # as we move in and out a disk during the test. This is because
    # after the reboot sle15 can recover the missing disk and we need
    # to compare with the expected_num_devs
    my $actual_num_devs = $config->{expected_num_devs};
    _check_lvm_partitioning($config);
    _check_raid1_partitioning($config, $actual_num_devs);
    _remove_raid_disk($config, $actual_num_devs);
    _reboot();
    $self->wait_boot;
    _check_raid_disks_after_reboot($config, $actual_num_devs);
    _restore_raid_disk($config);
}

sub _check_lvm_partitioning {
    my ($config) = @_;
    my $activelvm = script_output q[lvscan | awk '{print $2}' | sed s/\'//g];
    assert_equals $config->{lvm}->{lvpath}, $activelvm, "lv name is not the same. \n" . script_output q[lvscan];
    my $pvname = script_output q[pvscan -s | grep '/dev'];
    assert_equals $config->{lvm}->{pvname}, $pvname, "pv name is not the same.";
    record_info($config->{lvm}->{pvname});
}

sub _check_raid1_partitioning {
    my ($config, $actual_num_devs) = @_;
    record_info("raid1 name", $config->{raid1}->{name});
    assert_script_run 'mdadm --detail ' . $config->{lvm}->{pvname};
    assert_script_run 'grep \'md0 : active ' . $config->{raid1}->{level} . '\' /proc/mdstat';
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    assert_equals($active_devs, $actual_num_devs, "Active devices are different");

    for (@{$config->{disks}}) {
        my $line = script_output "mdadm --detail " . $config->{raid1}->{name} . " | awk '{ if((/$_/) && (\$5 ~ /active/) && (\$6 ~ /sync/)) {print}}'";
        assert_not_null($line, "$_ not active");
    }
}

sub _remove_raid_disk {
    my ($config, $actual_num_devs) = @_;
    assert_script_run "mdadm --manage $config->{raid1}->{name} --set-faulty $config->{raid1}->{disk_to_fail}";
    $actual_num_devs--;
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    assert_equals($actual_num_devs, $active_devs, "Active devices are different after set faulty device");

    assert_script_run 'mdadm --manage ' . $config->{raid1}->{name} . ' --remove ' . $config->{raid1}->{disk_to_fail};
    script_retry "mdadm --detail " . $config->{raid1}->{name} . " | grep 'Active Devices : 3'";
    my $removedDisk = script_output "mdadm --detail " . $config->{raid1}->{name} . " | awk '{ if((\$4 == " . $actual_num_devs . ") && (\$5 ~ /removed/)) {print}}'";
    assert_not_null($removedDisk, "$removedDisk should have been removed");
}

sub _reboot {
    record_info('system reboots');
    power_action('reboot', textmode => 'textmode');
}

sub _check_raid_disks_after_reboot {
    my ($config, $actual_num_devs) = @_;
    record_info('get state after reboot');
    select_console 'root-console';

    assert_script_run 'mdadm --detail ' . $config->{raid1}->{name};
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    # if the number of disk in raid1 list are not the same report a soft failure
    if ($active_devs != $config->{actual_num_devs}) {
        record_soft_failure 'bsc#1150370 - disk is restored during the booting' if is_sle('>=15');
    }
    else {
        assert_equals($actual_num_devs, $active_devs, "Active devices should be still " . $config->{expected_num_devs});
    }
}

sub _restore_raid_disk {
    my ($config) = @_;
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    if ($active_devs != $config->{expected_num_devs}) {
        assert_script_run 'mdadm --manage ' . $config->{raid1}->{name} . ' --add ' . $config->{raid1}->{disk_to_fail};
        script_retry "mdadm --detail $config->{raid1}->{name} | grep 'Active Devices : $config->{expected_num_devs}'";
        assert_script_run 'mdadm --detail ' . $config->{raid1}->{name};
    }
}

1;
