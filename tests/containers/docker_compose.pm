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
use version_utils qw(is_sle);
use containers::common;
use publiccloud::utils 'is_ondemand';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    add_suseconnect_product(get_addon_fullname('phub')) if is_sle();
    add_suseconnect_product(get_addon_fullname('python2')) if is_sle('=15-sp1');
    add_suseconnect_product(get_addon_fullname('pcm'), '12') if (is_sle('=12-sp5'));

    my $docker = $self->containers_factory('docker');

    record_info 'Test #1', 'Test: Installation';

    my $ret = zypper_call "in docker-compose", exitcode => [0, 4];
    if ($ret == 4) {
        # https://bugzilla.suse.com/show_bug.cgi?id=1186691#c29
        # Possible outcomes:
        #  nothing provides python-dockerpty >= 0.3.2 needed by docker-compose-1.2.0-5.1.noarch (12-SP5 s390x)
        #  nothing provides python-docker-py >= 1.0.0 needed by docker-compose-1.2.0-5.1.noarch (12-SP4 s390x)
        record_soft_failure "bsc#1186691 - docker-compose probably missing dependency";
        return 0;
    }

    if (script_output('docker-compose --version', proceed_on_failure => 1) =~ /distribution was not found/) {
        # Installation is ok, but when issuing docker-compose commands it throws:
        # pkg_resources.DistributionNotFound: The 'PyYAML<4,>=3.10' distribution was not found and is required by docker-compose
        # This happens only in 12-SP3 and 12-SP4 x86_64
        record_soft_failure "bsc#1186691 - docker-compose probably missing dependency";
        return 0;
    }

    # Prepare docker-compose.yml and haproxy.cfg
    assert_script_run 'mkdir -p dcproject; cd dcproject';
    assert_script_run("curl -O " . data_url("containers/docker-compose.yml"));
    assert_script_run("curl -O " . data_url("containers/haproxy.cfg"));

    file_content_replace("docker-compose.yml", REGISTRY => get_var('REGISTRY', 'docker.io/library'));
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
