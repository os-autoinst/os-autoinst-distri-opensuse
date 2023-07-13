# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify "There is no device mounted at '/'" Error Dialog is
# shown when saving partitioner settings with no root mounted.
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
    $partitioner = $testapi::distri->get_expert_partitioner();

    $partitioner->run_expert_partitioner();
    $partitioner->create_new_partition_table($test_data->{disks}[0]);
    $partitioner->accept_changes();

    assert_matches(qr/$test_data->{errors}->{no_root}/, $partitioner->get_error_dialog_text(),
        "'No root' Error Dialog did not appear, while it is expected.");
}

sub post_run_hook {
    save_screenshot;
    $partitioner->confirm_error_dialog();
    $partitioner->cancel_changes({accept_modified_devices_warning => 1});
}

1;
