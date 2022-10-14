# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test VM internal snapshot using virsh (create - restore - delete)
# Maintainer: Leon Guo <xguo@suse.com>

use base "virt_feature_test_base";
use strict;
use warnings;
use testapi;
use set_config_as_glue;
use utils;
use virt_utils;
use virt_autotest::common;
use virt_autotest::utils;

sub run_test {
    my ($self) = @_;
    #Snapshots are supported on KVM VM Host Servers only
    return unless is_kvm_host;

    my @guests = keys %virt_autotest::common::guests;
    foreach my $guest (@guests) {
        if (virt_autotest::utils::is_sev_es_guest($guest) ne 'notsev') {
            record_info "Skip internal snapshot on $guest", "SEV/SEV-ES guest $guest does not support internal snapshot";
            next;
        }
        my $type = check_guest_disk_type($guest);
        next if ($type == 1);
        record_info "virsh-snapshot", "Cleaning in case of rerun";
        if (script_run("virsh snapshot-list $guest | grep internal-snapshot-$guest-01") == 0) {
            assert_script_run "virsh snapshot-delete $guest --snapshotname internal-snapshot-$guest-01";
        }
        if (script_run("virsh snapshot-list $guest | grep internal-snapshot-$guest-02") == 0) {
            assert_script_run "virsh snapshot-delete $guest --snapshotname internal-snapshot-$guest-02";
        }
        record_info "virsh-snapshot", "Creating Internal Snapshot";
        assert_script_run "virsh snapshot-create-as $guest --name internal-snapshot-$guest-01";
        assert_script_run "virsh snapshot-current $guest | grep internal-snapshot-$guest-01";
        assert_script_run "virsh snapshot-list $guest | grep internal-snapshot-$guest-01";
        assert_script_run "virsh snapshot-create-as $guest --name internal-snapshot-$guest-02";
        assert_script_run "virsh snapshot-list $guest | grep internal-snapshot-$guest-02";

        record_info "virsh-snapshot", "Starting Internal Snapshot";
        assert_script_run "virsh snapshot-list $guest --tree| grep internal-snapshot-$guest-01";
        assert_script_run "virsh snapshot-revert $guest --snapshotname internal-snapshot-$guest-01";
        assert_script_run "virsh snapshot-info $guest --snapshotname internal-snapshot-$guest-01| grep 'Current.*yes'";
        assert_script_run "virsh snapshot-info $guest --snapshotname internal-snapshot-$guest-02| grep 'Current.*no'";
        assert_script_run "virsh snapshot-revert $guest --snapshotname internal-snapshot-$guest-02";
        assert_script_run "virsh snapshot-info $guest --snapshotname internal-snapshot-$guest-02| grep 'Current.*yes'";
        assert_script_run "virsh snapshot-info $guest --snapshotname internal-snapshot-$guest-01| grep 'Current.*no'";
        assert_script_run "virsh snapshot-list $guest --tree| grep internal-snapshot-$guest-01";

        record_info "virsh-snapshot", "Deleting Internal Snapshot";
        assert_script_run "virsh snapshot-delete $guest --snapshotname internal-snapshot-$guest-01";
        assert_script_run("! virsh snapshot-list $guest | grep internal-snapshot-$guest-01");
        assert_script_run "virsh snapshot-delete $guest --snapshotname internal-snapshot-$guest-02";
        assert_script_run("! virsh snapshot-list $guest | grep internal-snapshot-$guest-02");
    }
}

1;
