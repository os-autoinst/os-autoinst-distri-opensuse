# SUSE's openQA tests
#
# Copyright 2019-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iproute2 ca-certificates
# Summary: This is just bunch of random commands overviewing the public cloud instance
# We just register the system, install random package, see the system and network configuration
# This test module will fail at the end to prove that the test run will continue without rollback
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::zypper qw(pc_refresh pc_zypper_call pc_wait_quit);
use version_utils qw(is_sle is_sle_micro);

sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $instance = $args->{my_instance};

    $instance->ssh_script_run("hostname -f");
    $instance->ssh_assert_script_run("uname -a");

    $instance->ssh_assert_script_run("cat /etc/os-release");

    $instance->ssh_assert_script_run("ps aux | nl");

    # Workaround for missing iproute2 package in 15-SP4 CHOST images (bsc#1264714)
    if (get_required_var('FLAVOR') =~ 'GCE-CHOST-BYOS' && (is_sle("=15-SP4") || is_sle("=15-SP5")) && $instance->ssh_script_run('ip l') != 0) {
        record_soft_failure("bsc#1264714 Missing iproute2 package");
        pc_zypper_call($instance, 'in iproute2', timeout => 300);
    }

    my $ip_color = (is_sle('>=15-SP3')) ? '-c=never' : '';
    $instance->ssh_assert_script_run("ip $ip_color a s");
    $instance->ssh_assert_script_run("ip $ip_color r s");
    $instance->ssh_assert_script_run("ip $ip_color -6 r s");

    $instance->ssh_assert_script_run("cat /etc/hosts");
    $instance->ssh_assert_script_run("cat /etc/resolv.conf");

    $instance->ssh_assert_script_run("lsblk");

    # Check for bsc#1165915
    pc_refresh($instance);
    my $register = (is_sle_micro) ? "sudo transactional-update register --status-text" : "sudo SUSEConnect --status-text";
    # poo#204534: a background transactional-update task (e.g. snapper
    # cleanup) may still hold the lock right after boot/registration.
    pc_wait_quit($instance) if is_sle_micro;
    $instance->ssh_assert_script_run($register, timeout => 300);

    pc_zypper_call($instance, 'lr -d');

    collect_system_information($instance);
}

sub collect_system_information {
    my ($instance) = @_;

    # Collect various system information and pack them to instance_overview.tar
    my $dir = '/var/tmp/instance_overview';
    $instance->ssh_assert_script_run("mkdir -p $dir");
    $instance->ssh_assert_script_run("rpm -qa | tee $dir/rpm.list.txt", timeout => 90);
    $instance->ssh_assert_script_run("cat /proc/cpuinfo | tee $dir/cpuinfo.txt");
    $instance->ssh_assert_script_run("cat /proc/meminfo | tee $dir/meminfo.txt");
    $instance->ssh_assert_script_run("uname -a | tee $dir/uname.txt");
    $instance->ssh_assert_script_run("tar -czf /var/tmp/instance_overview.tar.gz -C /var/tmp instance_overview");
    $instance->upload_log('/var/tmp/instance_overview.tar.gz', failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
