# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use version_utils qw(is_caasp is_sle);
use containers::common;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my @runtimes = ("docker-runc");
    push @runtimes, "runc" if !is_sle('=15');

    record_info 'Setup', 'Setup the environment';
    # runC cannot create or extract the root filesystem on its own. Use Docker to create it.
    install_docker_when_needed;

    # create the rootfs directory
    assert_script_run('mkdir rootfs');

    # export busybox via Docker into the rootfs directory
    assert_script_run('docker export $(docker create busybox) | tar -C rootfs -xvf -');

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
    install_docker_when_needed;

    # remove leftover containers and images
    clean_container_host(runtime => 'docker');
}

1;
