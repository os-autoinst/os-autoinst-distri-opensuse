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

sub run {
    my $self = shift;

    select_console 'root-console';

    my $config = get_test_suite_data();
    my $expected_num_devs = scalar @{$config->{disks}};
    _check_lvm_partitioning($config);
    _check_raid1_partitioning($config, $expected_num_devs);
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

1;
