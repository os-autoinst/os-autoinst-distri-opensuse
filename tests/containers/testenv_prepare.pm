# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Running a pod with 2 containers under systemd
# Create a pod with name "test-pod0"
# Add 2 containers to the pod
# Use "podman generate systemd" to create systemd unit files
# Reload systemd via systemctl daemon-reload,
# Start and stop pod and container services
# Verify the connections between 2 created within the pod
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

    select_serial_terminal;
    my $busybox_container_image = "registry.opensuse.org/opensuse/busybox:latest";
    my $nginx_container_image = "registry.opensuse.org/opensuse/nginx:latest";

    assert_script_run('curl -sLf --create-dirs -vo /home/nginx/nginx.conf ' . data_url('containers/nginx/') . 'nginx.conf');
    assert_script_run('curl -sLf --create-dirs -vo /home/nginx/index.html ' . data_url('containers/nginx/') . 'index.html');

    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;

    # create a pod with 2 containers in it
    assert_script_run("podman pod create --name test-pod0 -p 80:80");

    assert_script_run("podman run -d --name nginx-container --pod test-pod0 -v /home/nginx/nginx.conf:/etc/nginx/nginx.conf:ro,z -v /home/nginx/index.html:/usr/share/nginx/html/index.html:ro,z  $nginx_container_image");
    assert_script_run("podman run -d --name Busybox-container --pod test-pod0 $busybox_container_image sleep infinity");

    validate_script_output('podman pod ps', sub { m/test-pod0/ });
    record_info('podman pod ps', script_output("podman pod ps"));
    record_info('podman ps', script_output("podman ps"));

    assert_script_run("podman generate systemd --new --files --name test-pod0");
    validate_script_output("ls *.service | wc -l", sub { m/3/ });

    assert_script_run("cp *.service /etc/systemd/system");
    assert_script_run("systemctl daemon-reload");
    # Start the pod service and make sure the service is running
    assert_script_run("systemctl enable --now pod-test-pod0.service", timeout => 120);
    systemctl("is-active pod-test-pod0.service");

    # Start 2 containers service and ensure its running
    assert_script_run("systemctl enable --now container-Busybox-container.service", timeout => 120);
    systemctl("is-active container-Busybox-container.service");

    assert_script_run("systemctl enable --now container-nginx-container.service", timeout => 120);
    systemctl("is-active container-nginx-container.service");
    # Verify the connection between containers in a pod
    validate_script_output("podman exec -it Busybox-container curl -s http://localhost:80", sub { m/Welcome to the nginx container!/ });
}

1;
