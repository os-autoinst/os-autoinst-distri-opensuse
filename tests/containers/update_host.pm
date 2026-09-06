# SUSE's openQA tests
#
# Copyright 2022-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Update host system
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use utils qw(zypper_call script_retry);
use version_utils qw(get_os_release is_sle);
use power_action_utils qw(power_action wait_boot_serial);
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures 'is_aarch64';
use Utils::Backends 'is_qemu';

sub disable_selinux {
    if (script_run('selinuxenabled') == 0) {
        record_info('Info', 'Disable SELinux');
        assert_script_run("sed -i 's/^SELINUX=.*\$/SELINUX=disabled/' /etc/selinux/config");
    }
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    record_info('uname', script_output('uname -a'));
    record_info('os-release', script_output('cat /etc/os-release'));
    my $update_timeout = 1200;

    my ($version, $sp, $host_distri) = get_os_release;
    if ($host_distri =~ /sles|opensuse/) {
        zypper_call("--quiet up", timeout => $update_timeout);
    } elsif ($host_distri eq 'ubuntu') {
        assert_script_run("dhclient -v");
        script_retry("apt-get update -y", timeout => $update_timeout);
        # We can't rely on DEBIAN_FRONTEND alone here due to
        # https://bugs.launchpad.net/ubuntu/+source/docker.io/+bug/1950314
        script_retry("yes yes | DEBIAN_FRONTEND=noninteractive apt-get upgrade -y", timeout => $update_timeout);
    } elsif ($host_distri eq 'centos') {
        # dhclient is no longer available in CentOS 10
        script_run("dhclient -v");
        script_retry("dnf update -y --nobest", timeout => $update_timeout);
    } elsif ($host_distri eq 'rhel') {
        script_retry("dnf update -y", timeout => $update_timeout);
        $self->disable_selinux();
    } else {
        die("Host OS not supported");
    }

    # Make sure the system reboots properly after update
    power_action('reboot', textmode => 1);
    # For some reason, we need to wait for some time in RES8 before waiting for boot
    sleep 60 if ($host_distri eq 'rhel');
    if (is_qemu && is_aarch64 && is_sle('=16.0')) {
        # Some aarch64 SUTs regenerate a bad grub.cfg (bsc#1140464) and hang
        # at a hidden-menu prompt; wait_boot_serial recovers from that.
        die 'System did not come back up after reboot' unless wait_boot_serial;
    } else {
        $self->wait_boot();
    }
    select_serial_terminal;
    record_info('uname', script_output('uname -a'));
    record_info('relaese', script_output('cat /etc/os-release'));
}


sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
