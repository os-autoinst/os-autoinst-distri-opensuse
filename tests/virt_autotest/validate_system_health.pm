# SUSE's openQA tests
#
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Do a basic examination to the host and guests after tests run
# Maintainer: Julie CAO <JCao@suse.com>, qe-virt@suse.de

use base "virt_feature_test_base";
use strict;
use warnings;
use testapi;
use utils;
use ipmi_backend_utils qw(reconnect_when_ssh_console_broken);
use Utils::Architectures;
use virt_autotest::common;
use virt_autotest::utils qw(start_guests check_host_health check_guest_health);
use virt_utils qw(collect_host_and_guest_logs);
use alp_workloads::kvm_workload_utils;
use version_utils qw(is_alp);

sub prepare_run_test {
    unless (defined(script_run("rm -f /root/{commands_history,commands_failure}", die_on_timeout => 0))) {
        reconnect_when_ssh_console_broken;
        alp_workloads::kvm_workload_utils::enter_kvm_container_sh if is_alp;
    }
    script_run("history -c");
}

sub run_test {
    return unless is_x86_64;

    my $self = shift;
    my %health_status = ();
    @health_status{(keys %virt_autotest::common::guests)} = ();
    $health_status{host} = check_host_health;
    foreach my $guest (grep { $_ ne 'host' } keys %health_status) {
        script_run("virsh start $guest", die_on_timeout => 0);
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
            collect_host_and_guest_logs(join(' ', grep { $_ ne 'host' } keys %health_status));
        }
        else {
            collect_host_and_guest_logs(join(' ', grep { $_ ne 'host' } @unhealthy_list));
        }
        $self->upload_coredumps;
        save_screenshot;
    }
    die "Host or guests are not healthy!" unless @unhealthy_list == 0;
}

sub post_fail_hook {
    my $self = shift;
    diag("Module validate_system_health post fail hook starts.");
    $self->junit_log_provision((caller(0))[3]);
    unless (defined(script_run("rm -f /root/{commands_history,commands_failure}", die_on_timeout => 0))) {
        reconnect_when_ssh_console_broken;
        alp_workloads::kvm_workload_utils::enter_kvm_container_sh if is_alp;
    }
    $self->upload_coredumps;
    upload_logs("/var/log/clean_up_virt_logs.log");
    upload_logs("/var/log/guest_console_monitor.log");
    script_run("rm -f -r /var/log/clean_up_virt_logs.log /var/log/guest_console_monitor.log");
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
