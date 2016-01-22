# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;

    # install the docker package
    script_run "zypper -n in docker && echo 'docker_installed' > /dev/$serialdev";
    die "docker install failed" unless wait_serial "docker_installed", 200;

    # start the docker daemon
    script_run "systemctl start docker && echo 'docker_started' > /dev/$serialdev";
    die "docker service start failed" unless wait_serial "docker_started", 200;

    # pull the alpine image
    script_run "docker pull alpine && echo 'docker_pull' > /dev/$serialdev";
    die "docker pull alpine image failed" unless wait_serial "docker_pull", 300;    # increase timeout, on systems using devicemapper as storage backend docker's initialization can take some time

    # make sure we can actually start a container
    script_run "docker run --rm alpine echo 'hello_from_container' > /dev/$serialdev";
    die "cannot start container" unless wait_serial "hello_from_container", 200;

    # make sure we can actually start a container
    script_run "docker run --rm alpine wget http://google.com && echo 'container_network_works' > /dev/$serialdev";
    die "network does not work inside of the container" unless wait_serial "container_network_works", 200;

    type_string "exit\n";
}

1;
# vim: set sw=4 et:
