# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test podman installation and extended usage in a Kubic system
#    Cover the following aspects of podman:
#      * podman daemon can be started
#      * images can be searched on the default registry
#      * images can be pulled from the default registry
#      * local images can be listed
#      * containers can be spawned
#      * containers state can be saved to an image
#      * network is working inside of the containers
#      * containers can be stopped
#      * containers can be deleted
#      * images can be deleted
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use version_utils;
use registration;
use containers::common;
use containers::utils;
use containers::container_images;
use publiccloud::utils;
use Utils::Systemd qw(systemctl disable_and_stop_service);

my $stop_firewall = 0;    # Post-run flag to stop the firewall (failsafe)

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $dir = "/root/DockerTest";
    my $podman = $self->containers_factory('podman');

    if ($self->firewall() eq 'firewalld') {
        zypper_call('in ' . $self->firewall()) if (is_publiccloud || is_jeos);
        systemctl('restart ' . $self->firewall());
        $stop_firewall = 1;
        $podman->check_containers_firewall();
    }

    # Run basic runtime tests
    basic_container_tests(runtime => $podman->runtime);
    # Build an image from Dockerfile and run it
    build_and_run_image(runtime => $podman, dockerfile => 'Dockerfile.python3', base => registry_url('python', '3'));

    # Clean container
    $podman->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup($self->firewall());
    select_console 'log-console';
    script_run "podman version | tee /dev/$serialdev";
    script_run "podman info --debug | tee /dev/$serialdev";
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    cleanup($self->firewall());
    $self->SUPER::post_run_hook;
}

# must ensure firewalld is stopped, if it is only enabled in this test (e.g. publiccloud test runs)
sub cleanup() {
    my $firewall = shift;
    disable_and_stop_service($firewall) if $stop_firewall;
}

1;
