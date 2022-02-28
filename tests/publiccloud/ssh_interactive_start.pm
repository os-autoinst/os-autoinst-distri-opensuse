# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh
# Summary: This tests will establish the tunnel and enable the SSH interactive console
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use publiccloud::ssh_interactive;
use testapi;
use utils;
use publiccloud::utils "select_host_console";

sub run {
    my ($self, $args) = @_;

    die("expect ssh serial") unless (get_var('SERIALDEV') =~ /ssh/);

    # Verify most important consoles
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

1;
