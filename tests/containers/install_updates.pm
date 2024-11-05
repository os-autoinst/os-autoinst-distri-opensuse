# SUSE's openQA tests
#
# Copyright 2021-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install available updates on the host image
# Maintainer: QE-C team <qa-c@suse.de>


use Mojo::Base qw(consoletest);
use testapi;
use utils;
use power_action_utils;
use version_utils qw(check_os_release get_os_release is_sle);

sub run {
    my ($self) = @_;
    my $update_timeout = 2400;
    my ($version, $sp, $host_distri) = get_os_release;
    # Check for bsc1232902, affecting the last 15-SP7 ISO, /etc/os-release paameters.
    my $is_bsc_1232902 = (is_sle("=15-sp7") and $host_distri =~ /^sle$/);

    # Update the system to get the latest released state of the hosts.
    # Check routing table is well configured
    if ($host_distri =~ /sles|opensuse/ or ($is_bsc_1232902)) {
        record_soft_failure("bsc#1232902, [Build GM] openQA SLES test fails in install_updates for unexpected os-release ID") if ($is_bsc_1232902);
        zypper_call("--quiet up", timeout => $update_timeout);
        ensure_ca_certificates_suse_installed() if is_sle();
    } elsif ($host_distri eq 'ubuntu') {
        # Sometimes, the host doesn't get an IP automatically via dhcp, we need force it just in case
        assert_script_run("dhclient -v");
        script_retry("apt-get update -qq -y", timeout => $update_timeout);
    } elsif ($host_distri eq 'centos') {
        assert_script_run("dhclient -v");
        script_retry("dnf update -q -y --nobest", timeout => $update_timeout);
    } elsif ($host_distri eq 'rhel') {
        script_retry("dnf update -q -y", timeout => $update_timeout);
    } else {
        die "Unsupported OS version";
    }

    # Perform system reboot to ensure the system is still ok
    my $prev_console = current_console();
    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 300);
    select_console($prev_console);
}

sub test_flags {
    return {fatal => 1};
}

1;
