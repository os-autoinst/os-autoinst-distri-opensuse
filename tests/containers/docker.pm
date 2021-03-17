# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: docker
# Summary: Test docker installation and extended usage
# - docker package can be installed
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
# Maintainer: Flavio Castelli <fcastelli@suse.com>, Panagiotis Georgiadis <pgeorgiadis@suse.com>, Sergio Lindo Mansilla <slindomansilla@suse.com>, Anna Minou <anna.minou@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use containers::common;
use version_utils qw(is_sle is_leap get_os_release);
use containers::utils;
use containers::container_images;

sub test_seccomp {
    my $no_seccomp = script_run('docker info | tee /tmp/docker_info.txt | grep seccomp');
    upload_logs('/tmp/docker_info.txt');
    if ($no_seccomp) {
        my $err_seccomp_support = 'boo#1072367 - Docker Engine does NOT have seccomp support';
        if (is_sle('<15') || is_leap('<15.0')) {
            record_info('WONTFIX', $err_seccomp_support);
        }
        else {
            die($err_seccomp_support);
        }
    }
    else {
        record_info('seccomp', 'Docker Engine supports seccomp');
    }
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();

    my $sleep_time = 90 * get_var('TIMEOUT_SCALE', 1);
    my $dir        = "/root/DockerTest";

    my ($running_version, $sp, $host_distri) = get_os_release();
    my $docker = containers::runtime->new(engine => 'docker');

    install_docker_when_needed($host_distri);
    test_seccomp();
    allow_selected_insecure_registries($docker);

    # Run basic docker tests
    basic_container_tests($docker);

    # Build an image from Dockerfile and test it
    test_containered_app($docker, dockerfile => 'Dockerfile.python3');

    # Clean container
    $docker->cleanup_system_host();
}

1;
