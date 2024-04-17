# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman engine
# Summary: Verify Podman nginx container is still running after upgrade
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::utils;
use containers::container_images;


sub run {
    my ($self) = @_;
    my $unit_name = 'test_nginx';
    my $container_name = 'nginx-Quadlet';
    select_serial_terminal;

    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;


    # validate the container
    my $target_version = get_var("TARGET_VERSION", get_required_var("VERSION"));
    validate_script_output("cat /etc/os-release", sub { m/VERSION="$target_version"/ });
    validate_script_output("podman ps", qr/$container_name/);
    validate_script_output("podman container inspect --format='{{.State.Running}}' $container_name", qr/true/);
    systemctl("is-active $unit_name.service");
    validate_script_output("curl -s http://localhost:80 | grep title", sub { m/Welcome to the nginx container!/ });
}

1;
