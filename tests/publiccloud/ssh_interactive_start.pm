# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh
# Summary: This tests will establish the tunnel and enable the SSH interactive console
#
# Maintainer: qa-c@suse.de

use Mojo::Base 'consoletest';
use testapi;
use utils;
use publiccloud::ssh_interactive "ssh_interactive_tunnel";
use version_utils;

sub run {
    my ($self, $args) = @_;
    die "tunnel-console requires the TUNELLED=1 setting" unless (is_tunneled());

    $self->{provider} = $args->{my_provider};    # required for cleanup

    # Initialize ssh tunnel for the serial device, if not yet happened
    ssh_interactive_tunnel($args->{my_instance}) if (get_var('_SSH_TUNNELS_INITIALIZED', 0) == 0);
    die("expect ssh serial") unless (get_var('SERIALDEV') =~ /ssh/);
    # The serial terminal needs to be activated manually, as it requires the $self argument
    $self->select_serial_terminal();
    enter_cmd('ssh -t sut');

    ## Test most important consoles to ensure they are working
    select_console('root-console');
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'), 180);
    assert_script_run('test $(id -un) == "root"');

    select_console('user-console');
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "' . $testapi::username . '"');

    $self->select_serial_terminal();
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "root"');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
