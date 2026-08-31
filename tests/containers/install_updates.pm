# SUSE's openQA tests
#
# Copyright 2021-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install available updates on the host image
# Maintainer: QE-C team <qa-c@suse.de>


use Mojo::Base 'consoletest';
use testapi;
use utils;
use power_action_utils;
use serial_terminal qw(get_login_message);
use version_utils qw(check_os_release get_os_release is_sle);

sub run {
    my ($self) = @_;
    my $update_timeout = 2400;
    my ($version, $sp, $host_distri) = get_os_release;

    # Update the system to get the latest released state of the hosts.
    # Check routing table is well configured
    if ($host_distri =~ /sles|opensuse/) {
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
    # On this SLE 16.0 aarch64/qemu image GRUB fails to init its configured
    # serial terminal ("serial port `com0' isn't found") and the video
    # framebuffer then genuinely stalls instead of ever painting a screen,
    # so wait_boot's needle-based checks hit a real "Stall detected" rather
    # than a missed match. Confirm boot completion over the serial console
    # instead, which stays live throughout.
    die 'System did not come back up after update reboot' unless wait_serial(get_login_message(), 300);
    $self->{in_wait_boot} = 0;
    reset_consoles;
    select_console($prev_console);
}

sub test_flags {
    return {fatal => 1};
}

1;
