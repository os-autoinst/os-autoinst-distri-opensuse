# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic test of SLE Micro in public cloud
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_byos registercloudguest);
use publiccloud::ssh_interactive 'select_host_console';
use utils qw(zypper_call systemctl);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    select_serial_terminal();
    my $provider = $self->provider_factory();
    $provider->{username} = 'suse';
    my $instance = $self->{my_instance} = $provider->create_instance();
    my $test_package = 'strace';
    registercloudguest($instance);
    $instance->run_ssh_command(cmd => 'zypper lr -d', timeout => 600);
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-generator');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled transactional-update.timer');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-add-ssh-keys');
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n pkg install ' . $test_package, timeout => 600);
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'rpm -q ' . $test_package);
    $instance->run_ssh_command(cmd => '! curl localhost:9090');
    $instance->run_ssh_command(cmd => 'sudo systemctl enable --now cockpit.socket');
    $instance->run_ssh_command(cmd => 'systemctl status cockpit.service | grep inactive');
    $instance->run_ssh_command(cmd => 'curl http://localhost:9090');
    $instance->run_ssh_command(cmd => 'systemctl status cockpit.service | grep active');
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n up', timeout => 360);
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'sudo sestatus | grep disabled');
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n setup-selinux');
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'sudo sestatus | grep enabled');
    $instance->run_ssh_command(cmd => 'sudo dmesg');
    $instance->run_ssh_command(cmd => 'sudo journalctl -p err');
}

1;
