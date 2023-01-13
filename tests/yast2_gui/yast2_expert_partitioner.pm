# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This test will check that creating, resizing, encrypting and
#          deleting a partition, a volume group and some logical volumes work as
#          intended.
# - Starts yast2 storage and select /dev/vdb device
# - Create a custom partition on /dev/vdb (200MiB, ext4)
# - Encrypt the partition created (password "susetesting")
# - Validate the partition creating by parsing the output of fdisk -l | grep
# "/dev/vdb1" inside a xterm
# - Starts yast2 storage and select /dev/vdb device
# - Select /dev/vdb1, select custom size and resize it to 170MiB
# - Validate the partition creating by parsing the output of fdisk -l | grep
# "/dev/vdb1" inside a xterm
# - Starts yast2 storage again, select /dev/vdb and delete partition created.
# Checks if device is unpartitioned afterwards.
# - Starts yast2 storage
# - Create a new VG "vgtest" on /dev/vdb
# - Inside "vgtest", create lv1, type: xfs
# - Inside "vgtest", create lv2, type: ext3, encrypt that partition with
# password "susetesting"
# - Inside "vgtest", create lv3, type btrfs, encrypt partition unless is SLE12SP4
# - Inside "vgtest", create lv4, type raw
# - Start xterm, run "lvdisplay /dev/vgtest/lv<number>" for each partition
# - Close xterm, start a new yast2 storage and delete all partitions created
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use YuiRestClient;
use scheduler 'get_test_suite_data';
use YaST::Module;

my $partitioner;
my $test_data;

sub pre_run_hook {
    $partitioner = $testapi::distri->get_expert_partitioner();
    $test_data = get_test_suite_data();
}

sub add_custom_partition {
    my $disk = $test_data->{disks}[0];
    YaST::Module::run_actions {
        $partitioner->confirm_only_use_if_familiar();
        $partitioner->add_partition_on_gpt_disk({
                disk => $disk->{name},
                partition => $disk->{partitions}[0]
        });
        $partitioner->show_summary_and_accept_changes();
    } module => 'storage', ui => 'qt';
}

sub verify_custom_partition {
    my $index = shift // 0;
    my $partition = $test_data->{disks}[0]->{partitions}[$index];
    my $name = "/dev/$partition->{name}";
    my $size = $partition->{size} =~ s/iB//r;

    x11_start_program('xterm');
    become_root;
    wait_still_screen 3;
    validate_script_output("fdisk -l | grep $name",
        sub { m/$name\s+\d+\s+\d+\s+\d+\s+$size.*/ });
    send_key "ctrl-d";
    wait_screen_change { send_key "ctrl-d" };
}

sub resize_custom_partition {
    YaST::Module::run_actions {
        $partitioner->confirm_only_use_if_familiar();
        $partitioner->resize_partition({
                disk => $test_data->{disks}[0]->{name},
                partition => $test_data->{disks}[0]->{partitions}[1]
        });
        $partitioner->show_summary_and_accept_changes();
    } module => 'storage', ui => 'qt';
}

sub verify_resized_partition {
    verify_custom_partition(1);
}

sub delete_resized_partition {
    YaST::Module::run_actions {
        $partitioner->confirm_only_use_if_familiar();
        $partitioner->delete_partition({
                disk => $test_data->{disks}[0]->{name},
                partition => $test_data->{disks}[0]->{partitions}[1]
        });
        $partitioner->show_summary_and_accept_changes();
    } module => 'storage', ui => 'qt';
}

sub add_logical_volumes {
    YaST::Module::run_actions {
        $partitioner->confirm_only_use_if_familiar();
        $partitioner->setup_lvm($test_data->{lvm});
        $partitioner->show_summary_and_accept_changes();
    } module => 'storage', ui => 'qt';
}

sub verify_logical_volumes {
    x11_start_program('xterm');
    become_root;
    wait_still_screen 3;
    my $vg = $test_data->{lvm}->{volume_groups}[0];
    assert_script_run "lvdisplay /dev/$vg->{name}/$_->{name}" for @{$vg->{logical_volumes}};
    send_key "ctrl-d";
    wait_screen_change { send_key "ctrl-d" };
}

sub delete_volume_group {
    YaST::Module::run_actions {
        $partitioner->confirm_only_use_if_familiar();
        my $vg = $test_data->{lvm}->{volume_groups}[0];
        $partitioner->delete_volume_group($vg->{name});
        $partitioner->show_summary_and_accept_changes();
    } module => 'storage', ui => 'qt';
}

sub run {
    select_console "x11";

    add_custom_partition;
    verify_custom_partition;
    resize_custom_partition;
    verify_resized_partition;
    delete_resized_partition;
    add_logical_volumes;
    verify_logical_volumes;
    delete_volume_group;
}

1;
