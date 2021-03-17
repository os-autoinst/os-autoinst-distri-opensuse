# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: runc docker-runc
# Summary: Test docker-runc and runc installation, and extended usage
#    Cover the following aspects of docker-runc and runc respectively:
#      * package can be installed
#      * create specification files
#      * run the container
#      * complete lifecycle (create, start, pause, resume, kill, delete)
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>, George Gkioulis <ggkioulis@suse.com>

use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_leap is_sle get_os_release);
use containers::common;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();

    my ($running_version, $sp, $host_distri) = get_os_release();

    my @runtimes = ();
    push @runtimes, "docker-runc" if (is_sle("<16") || is_leap("<16.0"));
    push @runtimes, "runc"        if !is_sle('=15');

    record_info 'Setup', 'Setup the environment';
    # runC cannot create or extract the root filesystem on its own. Use Docker to create it.
    install_docker_when_needed($host_distri);
    my $docker = containers::runtime->new(engine => 'docker');
    allow_selected_insecure_registries($docker);

    # create the rootfs directory
    assert_script_run('mkdir rootfs');

    # export alpine via Docker into the rootfs directory (see bsc#1152508)
    my $alpine = $docker->registry . "/library/alpine:3.6";
    $docker->_rt_assert_script_run('export $(docker create ' . $alpine . ') | tar -C rootfs -xvf -');

    foreach my $runc (@runtimes) {
        record_info "$runc", "Testing $runc";

        # If not testing docker-runc but docker-runc is installed, uninstall it
        if ($runc ne "docker-runc" && script_run("which docker-runc") == 0) {
            zypper_call('rm docker-runc');
        }

        test_container_runtime($runc);

        # uninstall the tested container runtime
        zypper_call("rm $runc");
    }

    # cleanup
    assert_script_run("rm -rf rootfs");

    # install docker and docker-runc if needed
    install_docker_when_needed($host_distri);

    # remove leftover containers and images
    $docker->cleanup_system_host();
}

1;
