# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify Warning Dialog for boot partition with too small size
# to contain kernel.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

my $partitioner;

sub run {
    my $test_data = get_test_suite_data();
    my $disk = $test_data->{disks}[0];
    $partitioner = $testapi::distri->get_expert_partitioner();

    $partitioner->run_expert_partitioner();
    foreach my $partition (@{$disk->{partitions}->{boot_small_for_kernel}}) {
        $partitioner->add_partition_on_gpt_disk({
                disk => $disk->{name},
                partition => $partition
        });
    }
    $partitioner->accept_changes();

    assert_matches(qr/$test_data->{errors}->{boot_small_for_kernel}/, $partitioner->get_error_dialog_text(),
        "Error Dialog for not enough space on '/boot' to contain a kernel did not appear, while it is expected.");
}

sub post_run_hook {
    save_screenshot;
    $partitioner->confirm_error_dialog();
    $partitioner->cancel_changes({accept_modified_devices_warning => 1});
}

1;

