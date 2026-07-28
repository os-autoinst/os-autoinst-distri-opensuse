# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for the on-demand instance's guest registration (cloud-regionsrv-client) to complete
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils qw(is_ondemand);
use publiccloud::ssh_interactive qw(select_host_console);

sub run {
    my ($self, $args) = @_;
    return unless (is_ondemand);

    select_host_console();

    $args->{my_instance}->wait_for_guestregister();
    $args->{my_instance}->ssh_script_run(cmd => "sudo zypper lr -u");
    $args->{my_instance}->ssh_script_run(cmd => "sudo zypper ls -u");
    $args->{my_instance}->ssh_script_run(cmd => "echo enough here");
    $args->{my_instance}->ssh_assert_script_run(cmd => "false");
}

sub test_flags {
    return {fatal => 1};
}

1;
