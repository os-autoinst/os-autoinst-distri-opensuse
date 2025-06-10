# SUSE's openQA tests
#
# Copyright 2021-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install available updates on the host image
# Maintainer: QE-C team <qa-c@suse.de>


use strict;
use warnings;
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
        if (script_run('rpm -q tar') && $version =~ '16') {
            record_soft_failure('bsc#1238784 - tar packet not installed by default');
            zypper_call('in tar');
        }
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
