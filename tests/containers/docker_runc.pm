# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: runc docker-runc
# Summary: Test docker-runc and runc installation, and extended usage
#    Cover the following aspects of docker-runc and runc respectively:
#      * package can be installed
#      * create specification files
#      * run the container
#      * complete lifecycle (create, start, pause, resume, kill, delete)
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_leap is_sle get_os_release is_transactional);
use containers::common;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    my $docker = $self->containers_factory('docker');
    my @runtimes = ();
    push @runtimes, "runc" if (is_leap(">15.1") or !is_sle('=15'));

    record_info 'Setup', 'Setup the environment';
    # runC cannot create or extract the root filesystem on its own. Use Docker to create it.

    # create the rootfs directory
    assert_script_run('mkdir rootfs');

    # export alpine via Docker into the rootfs directory (see bsc#1152508)
    my $registry = get_var('REGISTRY', 'docker.io');
    my $alpine = "$registry/library/alpine:3.6";
    assert_script_run('docker export $(docker create ' . $alpine . ') | tar -C rootfs -xvf -');

    foreach my $runc (@runtimes) {
        record_info "$runc", "Testing $runc";

        # If not testing docker-runc but docker-runc is installed, uninstall it
        if ($runc ne "docker-runc" && script_run("which docker-runc") == 0) {
            zypper_call('rm docker-runc');
        }

        test_container_runtime($runc);

        # uninstall the tested container runtime
        zypper_call("rm $runc") unless is_transactional;
    }

    # cleanup
    assert_script_run("rm -rf rootfs");

    # install docker and docker-runc if needed
    install_docker_when_needed($host_distri);

    # remove leftover containers and images
    $docker->cleanup_system_host();
}

1;
