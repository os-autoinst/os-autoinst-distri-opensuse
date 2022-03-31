# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic test of SLE Micro in public cloud
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils qw(is_byos select_host_console);
use utils qw(zypper_call systemctl);

sub run {
    my ($self) = @_;

    select_host_console();
    my $provider = $self->provider_factory();
    $provider->{username} = 'suse';
    my $instance = $self->{my_instance} = $provider->create_instance();
    $instance->run_ssh_command(cmd => 'sudo SUSEConnect -r ' . get_required_var('SCC_REGCODE'), timeout => 600);
    $instance->run_ssh_command(cmd => 'zypper lr', timeout => 600);
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-generator');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled transactional-update.timer');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-add-ssh-keys');
    $instance->run_ssh_command(cmd => 'transactional-update -n pkg install netcat-openbsd', timeout => 600);
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'nc -vz localhost 9090');
    $instance->run_ssh_command(cmd => 'systemctl enable --now cockpit.socket');
    $instance->run_ssh_command(cmd => 'systemctl status cockpit.service');
    $instance->run_ssh_command(cmd => 'curl http://localhost:9090 > out.html');
    $instance->run_ssh_command(cmd => 'systemctl status cockpit.service');
    $instance->run_ssh_command(cmd => 'transactional-update -n up');
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'sestatus');
    $instance->run_ssh_command(cmd => 'transactional-update -n setup-selinux');
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'sestatus');
    $instance->run_ssh_command(cmd => 'dmesg');
    $instance->run_ssh_command(cmd => 'journalctl -p err');

}

1;
