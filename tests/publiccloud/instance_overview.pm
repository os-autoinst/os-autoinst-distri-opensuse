# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: python3-ec2metadata iproute2 ca-certificates
# Summary: This is just bunch of random commands overviewing the public cloud instance
# We just register the system, install random package, see the system and network configuration
# This test module will fail at the end to prove that the test run will continue without rollback
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils;
use publiccloud::ssh_interactive;

sub run {
    my ($self, $args) = @_;
    # Preserve args for post_fail_hook
    $self->{provider} = $args->{my_provider};
    select_console 'root-console';

    script_run("hostname -f");
    assert_script_run("uname -a");

    assert_script_run("cat /etc/os-release");
    if (is_ec2) {
        script_run("ec2metadata --api latest --document | tee ec2metadata.txt");
        upload_logs("ec2metadata.txt");
    }

    assert_script_run("ps aux | nl");

    assert_script_run("ip a s");
    assert_script_run("ip -6 a s");
    assert_script_run("ip r s");
    assert_script_run("ip -6 r s");

    assert_script_run("cat /etc/hosts");
    assert_script_run("cat /etc/resolv.conf");

    if (script_run("zypper -n in traceroute bzip2") == 8) {
        record_soft_failure('bsc#1165915');
        assert_script_run('update-ca-certificates');
        zypper_call("in traceroute bzip2");
    }
    assert_script_run("traceroute -I gate.suse.cz", 90);

    assert_script_run("rpm -qa > /tmp/rpm.list.txt");
    upload_logs('/tmp/rpm.list.txt');
    upload_logs('/var/log/zypper.log');

    assert_script_run("SUSEConnect --status-text");
    zypper_call("lr -d");
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    # Destroy the public cloud instance
    ssh_interactive_leave();
    select_host_console(await_console => 0);
    $self->{provider}->cleanup();
}

1;
