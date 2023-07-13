# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for libvirtd service check tests for migration
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package services::libvirtd;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

#default guest vm params
our %guest_params = (
    name => 'nested_vm_test',
    ram => '',
    memory => '512',
    vcpus => '',
    'os-type' => '',
    disk => 'none',
    network => '',
    graphics => 'vnc',
    boot => 'cdrom',
);

sub remove_repo {
    my $repo_max_num = script_output("zypper lr | tail -1 | cut -d' ' -f1");
    zypper_call("lr -u");
    for (my $i = 1; $i < $repo_max_num + 1; $i = $i + 1) {
        zypper_call("rr 1");
    }
    script_run("zypper lr -u");
}
sub install_service {
    if (get_var("DISTRI") eq "opensuse") {
        remove_repo();
        my $version = script_output("grep VERSION= /etc/os-release | cut -d'=' -f2 | cut -d' ' -f1 | sed 's/\"//g'");
        zypper_call("ar http://download.opensuse.org/distribution/leap/$version/repo/oss/ main");
        zypper_call("ar http://download.opensuse.org/update/leap/$version/oss/ mainupdate");
        zypper_call("ref");
        zypper_call("lr -u");
    }
    zypper_call('in -t pattern kvm_server kvm_tools');
}

sub enable_service {
    systemctl 'enable libvirtd';
}

sub start_service {
    systemctl 'start libvirtd';
}

sub check_service {
    systemctl 'is-enabled libvirtd.service';
    systemctl 'is-active libvirtd';
}

sub initialize_virt_install_command {
    my $virt_install_cmd = "virt-install";
    foreach my $key (keys %guest_params) {
        if ($guest_params{$key} ne "") {
            $virt_install_cmd .= " " . "--" . $key . "=" . $guest_params{$key};
        }
    }
    return $virt_install_cmd;
}

sub pre_guest_env {
    my %hash = @_;
    my $guest = $hash{name};
    script_run("virsh net-start --network default");
    script_run("virsh net-autostart --network default");
    # start guest vm
    my $virt_cmd = initialize_virt_install_command();
    background_script_run($virt_cmd);
}

sub check_guest_status {
    my %hash = @_;
    my $guest = $hash{name};
    my $status = $hash{status};
    script_run("virsh list --all");
    script_retry("virsh list --all | grep $guest | grep $status", delay => 5, retry => 10, die => 1);
}

sub shutdown_guest {
    my %hash = @_;
    my $guest = $hash{name};
    #script_run("virsh shutdown $guest");
    script_run("virsh destroy $guest");
    # Wait until guests are terminated
    script_retry("! virsh list --all | grep $guest | grep running", delay => 1, retry => 5, die => 1);
}

# check libvirt service before and after migration
# stage is 'before' or 'after' system migration.
sub full_libvirtd_check {
    my (%hash) = @_;
    my $stage = $hash{stage};
    my $type = $hash{service_type};
    my $pkg = $hash{srv_pkg_name};
    if ($stage eq 'before') {
        install_service();
        common_service_action($pkg, $type, 'enable');
        common_service_action($pkg, $type, 'start');
        common_service_action($pkg, $type, 'status');
        common_service_action($pkg, $type, 'is-active');
        pre_guest_env(%guest_params);
        check_guest_status(%guest_params, status => 'running');
        shutdown_guest(%guest_params) if get_var("NESTED_VM_DOWN");
    }

    common_service_action($pkg, $type, 'is-enabled');
    common_service_action($pkg, $type, 'is-active');

    if ($stage eq 'after') {
        script_run("virsh list --all");
        # Since not set auto-start guest so guest status should be shut-down status after reboot/migration
        check_guest_status(%guest_params, status => 'shut');
    }
}

1;
