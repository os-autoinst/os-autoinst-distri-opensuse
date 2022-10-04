# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install available updates on the host image
# Maintainer: qac team <qa-c@suse.de>


use Mojo::Base qw(consoletest);
use testapi;
use utils;
use power_action_utils;
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
        script_retry("yum update -q -y --nobest", timeout => $update_timeout);
    } elsif ($host_distri eq 'rhel') {
        script_retry("yum update -q -y", timeout => $update_timeout);
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
