# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: test that containers are using SELinux
# Maintainer: QE Security <none@suse.de>
# Tags: poo#119827

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    # ensure that SELinux is enabled and in enforcing mode
    validate_script_output("sestatus", sub { m/SELinux\ status: .*enabled.* Current\ mode: .*enforcing/sx });

    my $image = 'registry.opensuse.org/opensuse/tumbleweed:latest';
    my $container_name = 'test_container_selinux';

    assert_script_run("podman pull $image", timeout => 300);
    assert_script_run("podman run --name $container_name -dt $image");

    validate_script_output("podman exec $container_name /bin/bash -c 'ps -eZ | grep container_t | grep bash'", sub { /.*container_t.*/ });
    validate_script_output("podman exec $container_name /bin/bash -c 'ls -Z |grep container_file_t'", sub { /.*container_file_t.*/ });
}

1;
