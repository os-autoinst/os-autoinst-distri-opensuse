# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify "There is no device mounted at '/'" Error Dialog is
# shown when saving partitioner settings with no root mounted.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

my $partitioner;

sub run {
    my $test_data = get_test_suite_data();
    my $disk      = $test_data->{disks}[0];
    $partitioner = $testapi::distri->get_expert_partitioner();

    $partitioner->run_expert_partitioner();
    $partitioner->add_partition_on_gpt_disk({
            disk      => $disk->{name},
            partition => $disk->{partitions}->{snapshots_small_root}
    });

    assert_matches(qr/$test_data->{warnings}->{snapshots_small_root}/, $partitioner->get_warning_label_text(),
        "'Root is too small for snapshots' Warning Dialog did not appear, while it is expected.");
}

sub post_run_hook {
    save_screenshot;
    $partitioner->confirm_warning();
    $partitioner->cancel_changes({accept_modified_devices_warning => 1});
}

1;
