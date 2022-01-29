# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

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

    assert_script_run("lsblk");

    # Install bzip2 to check for bsc#1165915
    if (script_run("zypper -n in bzip2") == 8) {
        record_soft_failure('bsc#1165915');
        assert_script_run('update-ca-certificates');
        zypper_call("in bzip2");
    }

    assert_script_run("SUSEConnect --status-text", 300);
    zypper_call("lr -d");

    collect_system_information($self);
}

sub collect_system_information {
    my ($self) = @_;

    # Collect various system information and pack them to instance_overview.tar
    script_run("cd /var/tmp");
    assert_script_run("mkdir -p instance_overview");
    assert_script_run("rpm -qa | tee instance_overview/rpm.list.txt", timeout => 90);
    assert_script_run("cat /proc/cpuinfo | tee instance_overview/cpuinfo.txt");
    assert_script_run("cat /proc/meminfo | tee instance_overview/meminfo.txt");
    assert_script_run("uname -a | tee instance_overview/uname.txt");
    $self->tar_and_upload_log("instance_overview/", "instance_overview.tar.gz");
    script_run("cd");
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_host_console(force => 1);
    # Destroy the public cloud instance
    $self->{provider}->cleanup();
}

1;
