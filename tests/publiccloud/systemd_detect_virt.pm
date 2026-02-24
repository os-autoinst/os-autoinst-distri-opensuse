# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run basic smoketest on publiccloud test instance
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use publiccloud::utils;
use version_utils;
use utils;
use Utils::Architectures qw(is_aarch64);

sub systemd_detect_virt_expected_output_virtual {
    my ($self) = @_;

    return "google" if is_gce;
    return "amazon" if is_ec2;
    return "microsoft" if is_azure;

    die "Unknown provider for systemd-detect-virt expected output";
}

sub assert_systemd_detect_virt_metal {
    my ($self, $rc, $output) = @_;

    my $not_expected_output = $self->systemd_detect_virt_expected_output_virtual();
    my $bsc;

    if (is_gce) {
        $bsc = "bsc#1244449 - known issue on GCE SLE <=15-SP6"
          if is_sle("<=15-SP6");

        $bsc = "bsc#1244449 - known issue on GCE SLE =15-SP7 with systemd without backported fix"
          if is_sle("=15-SP7");

        $bsc = "bsc#1258642 - known issue on GCE SLE =16.0 with systemd without backported fix"
          if is_sle("=16.0");
    }

    my $is_softfail = defined $bsc;

    if ($output eq $not_expected_output) {
        die "systemd-detect-virt returned virtualized environment output: $output"
          unless $is_softfail;

        record_soft_failure("systemd-detect-virt output '$output' on metal ($bsc)");
    }

    if ($rc != 1) {
        die "systemd-detect-virt unexpected rc: $rc (output: $output)"
          unless $is_softfail;

        record_soft_failure("systemd-detect-virt rc '$rc' on metal ($bsc)");
    }
}

sub assert_systemd_detect_virt_virtual {
    my ($self, $rc, $output) = @_;

    return if ($output eq "kvm");

    if ($output eq "none") {
        # Softfailures for known issues
        if (is_sle_micro("=6.0") && is_aarch64) {
            record_soft_failure("bsc#1256376 - systemd-detect-virt none on SLE Micro 6.0 aarch64");
            return;
        }
        if (is_sle_micro("=6.1") && is_aarch64) {
            record_soft_failure("bsc#1256377 - systemd-detect-virt none on SLE Micro 6.1 aarch64");
            return;
        }

        die "systemd-detect-virt detected 'none'";
    }

    die "systemd-detect-virt unexpected rc: $rc"
      unless $rc == 0;

    die "systemd-detect-virt unexpected output: $output"
      unless $output eq $self->systemd_detect_virt_expected_output_virtual();
}

sub assert_systemd_detect_virt {
    my ($self) = @_;

    my $rc = int(script_run('systemd-detect-virt'));
    my $output = script_output('systemd-detect-virt', proceed_on_failure => 1);

    record_info('systemd-detect-virt', "rc: $rc; output: $output");

    my $systemd_version = script_output('rpm -q systemd');

    record_info('systemd version', $systemd_version);

    if (get_var('PUBLIC_CLOUD_INSTANCE_TYPE') =~ /-metal$/) {
        $self->assert_systemd_detect_virt_metal($rc, $output);
    } else {
        $self->assert_systemd_detect_virt_virtual($rc, $output);
    }
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;

    $self->assert_systemd_detect_virt;
}

1;
