# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test VM external snapshot using virsh (create - restore - delete)
# Maintainer: Leon Guo <xguo@suse.com>
#

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
    my $vm_types = "sles|win";
    my $wait_script = "30";
    my $vm_hostnames = script_output("virsh list --all --name", $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array) {
        if (script_run("virsh list --all | grep $_ | grep shut") != 0) { script_run "virsh destroy $_", 90;
        }
    }

    #Wait for forceful shutdown of active guests
    sleep 60;

    my $vm_hostnames_inactive = script_output("virsh list --inactive --name", $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_inactive_array = split(/\n+/, $vm_hostnames_inactive);

    foreach my $guest (@guests) {
        if (virt_autotest::utils::is_sev_es_guest($guest) ne 'notsev') {
            record_info "Skip external snapshot on $guest", "SEV/SEV-ES guest $guest does not support external snapshot";
            next;
        }
        my $type = check_guest_disk_type($guest);
        next if ($type == 1);
        record_info "virsh-snapshot", "Creating External Snapshot of guest's disk";
        script_run("rm -f /var/lib/libvirt/images/$guest.{disk-only,memspec,diskspec}");    # ensure the files do not exist already

        my $vm_target_dev = script_output("virsh domblklist $guest --details | awk '/disk/{ print \$3 }' | head -n1");
        my $pre_snapshot_cmd = "virsh snapshot-create-as $guest";
        my $diskspec_diskonly = "$vm_target_dev,snapshot=external,file=/var/lib/libvirt/images/$guest.disk-only";
        $pre_snapshot_cmd = $pre_snapshot_cmd . " --disk-only ";
        $pre_snapshot_cmd = $pre_snapshot_cmd . " --diskspec " . $diskspec_diskonly;
        my $ex_snapshot_name = "external-snapshot-$guest";
        $pre_snapshot_cmd = $pre_snapshot_cmd . " --name " . $ex_snapshot_name;
        assert_script_run "$pre_snapshot_cmd";
        assert_script_run "virsh snapshot-list $guest | grep $ex_snapshot_name";

        record_info "virsh-snapshot", "Creating Live External Snapshot of guest's memory and disk state";
        #required guests as running status to create Live External Snapshot
        foreach (@vm_hostnames_inactive_array) {
            if (script_run("nmap $guest -PN -p ssh | grep open") != 0) {
                assert_script_run "virsh start $guest", 60;
                script_retry "nmap $guest -PN -p ssh | grep open", delay => 3, retry => 60;
            }
        }
        my $pre_esnapshot_cmd = "virsh snapshot-create-as $guest";
        my $live_es_memspec = "snapshot=external,file=/var/lib/libvirt/images/$guest.memspec";
        $pre_esnapshot_cmd = $pre_esnapshot_cmd . " --live ";
        $pre_esnapshot_cmd = $pre_esnapshot_cmd . " --memspec " . $live_es_memspec;
        my $live_es_diskspec = "$vm_target_dev,snapshot=external,file=/var/lib/libvirt/images/$guest.diskspec";
        $pre_esnapshot_cmd = $pre_esnapshot_cmd . " --diskspec " . $live_es_diskspec;
        my $live_es_name = "external-snapshot-live-$guest";
        $pre_esnapshot_cmd = $pre_esnapshot_cmd . " --name " . $live_es_name;
        assert_script_run "$pre_esnapshot_cmd";
        assert_script_run "virsh snapshot-list $guest | grep $live_es_name";

        record_info "virsh-snapshot", "SKIP - No support to start external snapshot";
        record_info "virsh-snapshot", "SKIP - No support to delete external snapshot";
    }
}

1;
