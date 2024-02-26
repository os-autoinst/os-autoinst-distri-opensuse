# SUSE's openQA tests
#
# Copyright 2017-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker-compose
# Summary: Test docker-compose installation
#    Cover the following aspects of docker-compose:
#      * package can be installed
#      * Required images can be pulled
#      * All containers can be executed
#      * Both internal and external volumes can be attached
#      * Various networks can be created - the containers can communicate through
#      * Single commands can be executed inside of running container
#      * Exposed ports are accessible from outside of a container
#      * Logs can be retrieved
# Maintainer: QE-C team <qa-c@suse.de>


use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use registration;
use utils;
use containers::common;
use version_utils qw(is_transactional);

sub basic_test {
    my ($runtime, $rootless) = @_;
    my $opts = $rootless ? "--user" : "";

    systemctl "start $opts podman.socket" if ($runtime eq "podman");

    # Prepare docker-compose.yml and haproxy.cfg
    assert_script_run 'mkdir -p dcproject; cd dcproject';
    assert_script_run("curl -O " . data_url("containers/docker-compose.yml"));
    assert_script_run("curl -O " . data_url("containers/haproxy.cfg"));

    file_content_replace("docker-compose.yml", REGISTRY => get_var('REGISTRY', 'docker.io'));
    assert_script_run "$runtime compose pull", 600;

    # Start all containers in background
    # Wait for still screen so we sure everything is stable
    assert_script_run "$runtime compose up -d", 120;
    wait_still_screen stilltime => 15, timeout => 180;

    assert_script_run "$runtime compose ps";
    assert_script_run "$runtime compose top";

    # Send HTTP request to haproxy - it should be proxied to nginx
    assert_script_run 'curl -s http://127.0.0.1:8080/ | grep "Welcome to nginx!"';

    # Change the index.html in nginx /usr/share/nginx/html volume a check it
    assert_script_run "$runtime compose exec nginx /bin/sh -c 'echo Hello > /usr/share/nginx/html/index.html'";
    assert_script_run 'curl -s http://127.0.0.1:8080/ | grep "Hello"';

    assert_script_run "$runtime compose logs | tee $runtime-compose-logs.txt";
    upload_logs "$runtime-compose-logs.txt";

    assert_script_run "$runtime compose down", 180;

    systemctl "stop $opts podman.socket" if ($runtime eq "podman");
}

sub run {
    my ($self, $args) = @_;
    my $runtime = $args->{runtime};

    select_serial_terminal;

    my $engine = $self->containers_factory($runtime);

    install_packages('docker-compose');

    validate_script_output("$runtime compose version", qr/version 2/);

    basic_test($runtime, 0);

    if ($runtime eq "podman") {
        if (is_transactional) {
            select_console "user-console";
        } else {
            select_user_serial_terminal();
        }
        basic_test($runtime, 1);
    }

    $engine->cleanup_system_host();
}

1;
