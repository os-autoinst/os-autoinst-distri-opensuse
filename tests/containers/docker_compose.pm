# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
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
# Maintainer: qac team <qa-c@suse.de>


use Mojo::Base 'containers::basetest';
use testapi;
use registration;
use utils;
use version_utils qw(is_leap is_sle);
use containers::common;
use publiccloud::utils 'is_ondemand';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    add_suseconnect_product(get_addon_fullname('phub')) if is_sle();
    add_suseconnect_product(get_addon_fullname('python2')) if is_sle('=15-sp1');
    # Some python dependencies for SLE 12-SPx are in Public Cloud module
    add_suseconnect_product(get_addon_fullname('pcm'), '12') if (is_sle('<15'));

    my $docker = $self->containers_factory('docker');

    record_info 'Test #1', 'Test: Installation';
    my $pkg = (is_sle || is_leap) ? 'docker-compose' : 'docker-compose-switch';
    zypper_call "in $pkg";

    # Prepare docker-compose.yml and haproxy.cfg
    assert_script_run 'mkdir -p dcproject; cd dcproject';
    assert_script_run("curl -O " . data_url("containers/docker-compose.yml"));
    assert_script_run("curl -O " . data_url("containers/haproxy.cfg"));

    file_content_replace("docker-compose.yml", REGISTRY => get_var('REGISTRY', 'docker.io'));
    assert_script_run 'docker-compose pull', 600;

    # Start all containers in background
    # Wait for still screen so we sure everything is stable
    assert_script_run 'docker-compose up -d', 120;
    wait_still_screen stilltime => 15, timeout => 180;

    assert_script_run 'docker-compose ps';
    assert_script_run 'docker-compose top';

    # Send HTTP request to haproxy - it should be proxied to nginx
    assert_script_run 'curl -s http://127.0.0.1:8080/ | grep "Welcome to nginx!"';

    # Change the index.html in nginx /usr/share/nginx/html volume a check it
    assert_script_run 'docker-compose exec nginx /bin/sh -c "echo \"Hello\" > /usr/share/nginx/html/index.html"';
    assert_script_run 'curl -s http://127.0.0.1:8080/ | grep "Hello"';

    assert_script_run 'docker-compose logs > logs.txt';
    upload_logs "logs.txt";

    assert_script_run 'docker-compose down', 180;
    assert_script_run 'cd';

    # De-registration is disabled for on-demand instances
    remove_suseconnect_product(get_addon_fullname('phub')) if (is_sle() && !is_ondemand());
    remove_suseconnect_product(get_addon_fullname('python2')) if (is_sle('=15-sp1') && !is_ondemand());
    $docker->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    assert_script_run 'docker-compose logs > logs.txt';
    upload_logs 'logs.txt';
    $self->SUPER::post_fail_hook;
}

1;
