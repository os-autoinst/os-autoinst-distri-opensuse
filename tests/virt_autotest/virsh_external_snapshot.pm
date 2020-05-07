# SUSE's openQA tests
#
# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

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
use xen;

sub run_test {
    my ($self) = @_;
    #Snapshots are supported on KVM VM Host Servers only
    return unless check_var("REGRESSION", "qemu-hypervisor") || check_var("SYSTEM_ROLE", "kvm");

    my $vm_types           = "sles|win";
    my $wait_script        = "30";
    my $get_vm_hostnames   = "virsh list --all | grep -E \"${vm_types}\" | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array) {
        if (script_run("virsh list --all | grep $_ | grep shut") != 0) { script_run "virsh destroy $_", 90;
        }
    }

    #Wait for forceful shutdown of active guests
    sleep 60;

    my $get_vm_hostnames_inactive   = "virsh list --inactive | grep -E \"${vm_types}\" | awk \'{print \$2}\'";
    my $vm_hostnames_inactive       = script_output($get_vm_hostnames_inactive, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_inactive_array = split(/\n+/, $vm_hostnames_inactive);

    foreach my $guest (keys %xen::guests) {
        my $type = check_guest_disk_type($guest);
        next if ($type == 1);
        record_info "virsh-snapshot", "Creating External Snapshot of guest's disk";
        my $vm_target_dev     = script_output("virsh domblklist $guest --details | awk '/disk/{ print \$3 }'");
        my $pre_snapshot_cmd  = "virsh snapshot-create-as $guest";
        my $diskspec_diskonly = "$vm_target_dev,snapshot=external,file=/var/lib/libvirt/images/$guest.disk-only";
        $pre_snapshot_cmd = $pre_snapshot_cmd . " --disk-only ";
        $pre_snapshot_cmd = $pre_snapshot_cmd . " --diskspec " . $diskspec_diskonly;
        my $ex_snapshot_name = "external-snapshot-$guest";
        $pre_snapshot_cmd = $pre_snapshot_cmd . " --name " . $ex_snapshot_name;
        assert_script_run "$pre_snapshot_cmd";
        assert_script_run "virsh snapshot-list $guest | grep $ex_snapshot_name";

        record_info "virsh-snapshot", "Creating Live External Snapshot of guest's memory and disk state";
        #required guests as running status to create Live External Snapshot
        script_run("virsh start $_") foreach (@vm_hostnames_inactive_array);
        my $pre_esnapshot_cmd = "virsh snapshot-create-as $guest";
        my $live_es_memspec   = "snapshot=external,file=/var/lib/libvirt/images/$guest.memspec";
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
