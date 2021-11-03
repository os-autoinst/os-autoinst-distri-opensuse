# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker
# Summary: Test docker installation and extended usage
# - docker package can be installed
# - firewall is configured correctly
# - docker daemon can be started
# - images can be searched on the Docker Hub
# - images can be pulled from the Docker Hub
# - local images can be listed (with and without tag)
# - containers can be run and created
# - containers state can be saved to an image
# - network is working inside of the containers
# - containers can be stopped
# - containers can be deleted
# - images can be deleted
# - build a docker image
# - attach a volume
# - expose a port
# - test networking outside of host
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use containers::common;
use version_utils qw(is_sle is_leap is_tumbleweed is_jeos get_os_release);
use containers::utils;
use containers::container_images;
use publiccloud::utils;

my $stop_firewall = 0;    # Post-run flag to stop the firewall (failsafe)

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $sleep_time = 90 * get_var('TIMEOUT_SCALE', 1);
    my $dir = "/root/DockerTest";

    my ($running_version, $sp, $host_distri) = get_os_release;
    my $engine = $self->containers_factory('docker');
    install_docker_when_needed($host_distri);
    test_seccomp();
    $engine->configure_insecure_registries();

    if ($self->firewall() eq 'firewalld') {
        # on publiccloud we need to install firewalld first
        install_and_start_firewalld() if (is_publiccloud || is_jeos);
        check_docker_firewall();
    }

    # Run basic runtime tests
    basic_container_tests(runtime => $engine->runtime);
    # Build an image from Dockerfile and run it
    build_and_run_image(runtime => $engine, dockerfile => 'Dockerfile.python3', base => registry_url('python', '3'));

    # Clean container
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_run_hook;
}

sub install_and_start_firewalld() {
    zypper_call('install firewalld');
    systemctl('start firewalld');
    systemctl('restart docker');
    $stop_firewall = 1;
}

# must ensure firewalld is stopped, if it is only enabled in this test (e.g. publiccloud test runs)
sub cleanup() {
    script_run('systemctl stop firewalld; systemctl restart docker') if $stop_firewall;
}

1;
