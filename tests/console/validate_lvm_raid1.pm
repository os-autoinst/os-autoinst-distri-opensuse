# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: RAID1 on LVM partition validation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "y2_module_consoletest";
use testapi;
use utils;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';
use version_utils "is_sle";
use power_action_utils 'power_action';

sub run {
    my $self = shift;

    select_console 'root-console';

    my $config = get_test_suite_data();
    my $expected_num_devs = scalar @{$config->{disks}};
    _check_lvm_partitioning($config);
    _check_raid1_partitioning($config, $expected_num_devs);
    _remove_raid_disk($config, $expected_num_devs);
    _reboot();
    $self->wait_boot;
    _check_raid_disks_after_reboot($config, $expected_num_devs);
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
    my ($config, $expected_num_devs) = @_;
    record_info("raid1 name", $config->{raid1}->{name});
    assert_script_run 'mdadm --detail ' . $config->{lvm}->{pvname};
    assert_script_run 'grep \'md0 : active ' . $config->{raid1}->{level} . '\' /proc/mdstat';
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    assert_equals($active_devs, $expected_num_devs, "Active devices are different");

    for (@{$config->{disks}}) {
        my $line = script_output "mdadm --detail " . $config->{raid1}->{name} . " | awk '{ if((/$_/) && (\$5 ~ /active/) && (\$6 ~ /sync/)) {print}}'";
        assert_not_null($line, "$_ not active");
    }
}

sub _remove_raid_disk {
    my ($config, $expected_num_devs) = @_;
    assert_script_run "mdadm --manage $config->{raid1}->{name} --set-faulty $config->{raid1}->{disk_to_fail}";
    $expected_num_devs--;
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    assert_equals($expected_num_devs, $active_devs, "Active devices are different after set faulty device");

    assert_script_run 'mdadm --manage ' . $config->{raid1}->{name} . ' --remove ' . $config->{raid1}->{disk_to_fail};
    script_retry "mdadm --detail " . $config->{raid1}->{name} . " | grep 'Active Devices : $expected_num_devs'";
    my $removedDisk = script_output "mdadm --detail " . $config->{raid1}->{name} . " | awk '{ if((\$4 == " . $expected_num_devs . ") && (\$5 ~ /removed/)) {print}}'";
    assert_not_null($removedDisk, "$removedDisk should have been removed");
}

sub _reboot {
    record_info('system reboots');
    power_action('reboot', textmode => 'textmode');
}

sub _check_raid_disks_after_reboot {
    my ($config, $expected_num_devs) = @_;
    record_info('get state after reboot');
    select_console 'root-console';

    assert_script_run 'mdadm --detail ' . $config->{raid1}->{name};
    my $active_devs = script_output("mdadm --detail " . $config->{raid1}->{name} . " |grep \"Active Devices\" |awk '{ print \$4 }'");
    # if the deactivated disk is not reactivated after reboot, run _restore_raid_disk
    unless ($active_devs == $expected_num_devs) {
        _restore_raid_disk($config, $expected_num_devs);
    }
    else {
        record_info("Autorecovery", "$config->{raid1}->{disk_to_fail} was automatically recovered after reboot.");
    }
}

sub _restore_raid_disk {
    my ($config, $expected_num_devs) = @_;
    assert_script_run 'mdadm --manage ' . $config->{raid1}->{name} . ' --add ' . $config->{raid1}->{disk_to_fail};
    script_retry "mdadm --detail $config->{raid1}->{name} | grep 'Active Devices : $expected_num_devs'";
    assert_script_run 'mdadm --detail ' . $config->{raid1}->{name};
}

1;
