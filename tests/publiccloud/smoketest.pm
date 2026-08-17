# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run basic smoketest on publiccloud test instance
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive 'select_host_console';

sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $instance = $args->{my_instance};

    # Check if systemd completed sucessfully
    $instance->ssh_assert_script_run('sudo journalctl -b | grep "Reached target Basic System"');
    # Additional basic commands to verify the instance is healthy
    my $output = $instance->ssh_script_output('echo "ping"');
    die("Unexpected output of 'echo ping': $output") unless ($output =~ m/ping/);
    $instance->ssh_assert_script_run('uname -a');
}

1;
