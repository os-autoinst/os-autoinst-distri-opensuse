# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Running Podman nginx container under systemd
# Create my_nginx.container file
# Inform systemd about the new unit file and this creates a nginx.service
# Start the created nginx service.
# Verify the status of the nginx service.
# Publish the port the container is running on.
# Fetch a predefined website.
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

    select_serial_terminal;
    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    assert_script_run('curl -sLf --create-dirs -vo /home/nginx/nginx.conf ' . data_url('containers/nginx/') . 'nginx.conf');
    assert_script_run('curl -sLf --create-dirs -vo /home/nginx/index.html ' . data_url('containers/nginx/') . 'index.html');
    assert_script_run('curl -sLf  -o /etc/containers/systemd/test_nginx.container ' . data_url('containers/nginx/') . 'test_nginx.container');

    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;

    # create files for generator
    record_info("quadlet version", script_output("$quadlet -version"));
    record_info('Unit', script_output("$quadlet -v -dryrun"));

    # start the generator and check whether the files are generated
    assert_script_run("systemctl daemon-reload");
    # start the container
    systemctl("is-active $unit_name.service", expect_false => 1);
    assert_script_run("systemctl start $unit_name.service", timeout => 120);
    systemctl("is-active $unit_name.service");
    record_info('Exposed port for nginx-Quadlet container', script_output("podman inspect nginx-Quadlet -f '{{ .NetworkSettings.Ports }}'"));
    validate_script_output("podman ps", qr/nginx-Quadlet/);
    validate_script_output("curl -s http://localhost:80 | grep title", sub { m/Welcome to the nginx container!/ });
}

1;
