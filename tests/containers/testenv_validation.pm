# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman engine
# Summary: Verify Pod and containers within pods are still running after upgrade
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::utils;
use containers::container_images;


sub run {
    my ($self) = @_;
    my $nginx_container = "nginx-container";
    my $tumbleweed_container = "Tumbleweed-container";
    select_serial_terminal;

    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;


    # validate the container
    my $target_version = get_var("TARGET_VERSION", get_required_var("VERSION"));
    validate_script_output('podman pod ps', sub { m/test-pod0/ });
    record_info('podman pod ps', script_output("podman pod ps"));
    record_info('podman ps', script_output("podman ps"));

    # Ensure the pod and containers are running
    systemctl("is-active pod-test-pod0.service");
    systemctl("is-active container-Tumbleweed-container.service");
    systemctl("is-active container-nginx-container.service");

    # Verify the connection between containers in a pod
    validate_script_output("podman exec -it Tumbleweed-container curl -s http://localhost:80", sub { m/Welcome to the nginx container!/ });
}

1;
