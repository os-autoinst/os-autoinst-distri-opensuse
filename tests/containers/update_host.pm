# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Update host system
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use utils qw(zypper_call script_retry);
use version_utils qw(get_os_release);
use power_action_utils qw(power_action);
use testapi;
use serial_terminal 'select_serial_terminal';

sub disable_selinux {
    if (script_run('selinuxenabled') == 0) {
        record_info('Info', 'Disable SELinux');
        assert_script_run("sed -i 's/^SELINUX=.*\$/SELINUX=disabled/' /etc/selinux/config");
    }
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $update_timeout = 1200;

    my ($version, $sp, $host_distri) = get_os_release;
    if ($host_distri =~ /sles|opensuse/) {
        zypper_call("--quiet up", timeout => $update_timeout);
    } elsif ($host_distri eq 'ubuntu') {
        assert_script_run("dhclient -v");
        script_retry("apt-get update -y", timeout => $update_timeout);
    } elsif ($host_distri eq 'centos') {
        assert_script_run("dhclient -v");
        script_retry("yum update -y --nobest", timeout => $update_timeout);
    } elsif ($host_distri eq 'rhel') {
        script_retry("yum update -y", timeout => $update_timeout);
        $self->disable_selinux();
    } else {
        die("Host OS not supported");
    }

    # Make sure the system reboots properly after update
    power_action('reboot', textmode => 1);
    # For some reason, we need to wait for some time in RES8 before waiting for boot
    sleep 60 if ($host_distri eq 'rhel');
    $self->wait_boot();
    select_serial_terminal;
    record_info('uname', script_output('uname -a'));
    record_info('relaese', script_output('cat /etc/os-release'));
}


sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
