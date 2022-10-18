# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test SLE Micro Rancher image
#   This image is used as a base to build a Rancher Harverster container image.
#   Then, that image will be used to build a Host OS on top, so
#   it includes the kernel, firmware, bootloader, etc.
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $image = get_var('CONTAINER_IMAGE_TO_TEST', 'registry.suse.de/suse/sle-15-sp3/update/products/microos52/update/cr/totest/images/suse/sle-micro-rancher/5.2:latest');

    assert_script_run("podman pull $image");
    assert_script_run("podman run --name slem_image -dt $image");

    record_info('Kernel', 'Test that kernel files are present');
    validate_script_output("podman exec slem_image /bin/sh -c 'ls /boot'", sub { /initrd/ });
    validate_script_output("podman exec slem_image /bin/sh -c 'ls /boot'", sub { /vmlinuz/ });

    record_info('Firmware', 'Test that /lib/firmware directory is not empty');
    assert_script_run("podman exec slem_image /bin/sh -c 'test -d /lib/firmware'");
    assert_script_run("podman exec slem_image /bin/sh -c '[[ -n \"`ls -A /lib/firmware`\" ]]'");

    record_info('grub', "Test that /etc/default/grub exists and it's not empty");
    assert_script_run("podman exec slem_image /bin/sh -c 'test -s /etc/default/grub'");

    record_info('repos', 'Image should come with empty repos');
    validate_script_output("podman exec slem_image /bin/sh -c 'zypper lr' 2>&1", sub { /No repositories defined/ }, proceed_on_failure => 1);
    assert_script_run("podman exec slem_image /bin/sh -c '[[ -z \"`ls -A /etc/zypp/repos.d`\" ]]'");
}

sub test_flags {
    return {fatal => 1};
}

1;
