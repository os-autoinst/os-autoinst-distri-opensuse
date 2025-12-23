# SUSE's openQA tests
#
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Do a basic examination to the host and guests after tests run
# Maintainer: Julie CAO <JCao@suse.com>, qe-virt@suse.de

use base "consoletest";
use testapi;
use utils;
use Utils::Logging qw(upload_coredumps);
use ipmi_backend_utils qw(reconnect_when_ssh_console_broken);
use Utils::Architectures;
use virt_autotest::common;
use virt_autotest::utils qw(start_guests check_host_health check_guest_health);
use virt_utils qw(collect_host_and_guest_logs);
use alp_workloads::kvm_workload_utils;
use version_utils qw(is_alp);

sub run {
    return unless is_x86_64 || is_alp;

    my $self = shift;
    my %health_status = ();
    @health_status{(keys %virt_autotest::common::guests)} = ();
    $health_status{host} = check_host_health;
    foreach my $guest (grep { $_ ne 'host' } keys %health_status) {
        script_run("timeout 20 virsh start $guest");
        if (script_retry("nmap $guest -PN -p ssh | grep open", delay => 2, retry => 60, die => 0) == 0) {
            $health_status{$guest} = check_guest_health($guest);
        }
        else {
            $health_status{$guest} = "Unreachable";
        }
        record_info("Failed guest", "$guest: $health_status{$guest}", result => 'fail') unless $health_status{$guest} eq 'pass';
    }
    my @unhealthy_list = grep { $health_status{$_} ne 'pass' } keys %health_status;

    # Upload logs on x86_64
    if (get_var('FORCE_UPLOAD_LOGS') || @unhealthy_list != 0) {
        if (get_var('FORCE_UPLOAD_LOGS')) {
            collect_host_and_guest_logs(guest => join(' ', grep { $_ ne 'host' } keys %health_status), full_supportconfig => get_var('FULL_SUPPORTCONFIG', 1), token => '_validate_system_health');
        }
        else {
            collect_host_and_guest_logs(guest => join(' ', grep { $_ ne 'host' } @unhealthy_list), full_supportconfig => get_var('FULL_SUPPORTCONFIG', 1), token => '_validate_system_health');
        }
        $self->upload_coredumps;
        save_screenshot;
    }
    die "Host or guests are not healthy!" unless @unhealthy_list == 0;
}

sub post_fail_hook {
    my $self = shift;
    diag("Module validate_system_health post fail hook starts.");
    enter_cmd "rm -f /root/{commands_history,commands_failure}; echo DONE > /dev/$serialdev";
    unless (defined(wait_serial 'DONE', timeout => 30)) {
        reconnect_when_ssh_console_broken;
        alp_workloads::kvm_workload_utils::enter_kvm_container_sh if is_alp;
    }
    upload_coredumps;
    upload_logs("/var/log/clean_up_virt_logs.log");
    upload_logs("/var/log/guest_console_monitor.log");
    script_run("rm -f -r /var/log/clean_up_virt_logs.log /var/log/guest_console_monitor.log");
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
