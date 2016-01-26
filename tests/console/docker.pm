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
    select_console 'root-console';

    # install the docker package
    assert_script_run "zypper -n in docker", 200;

    # start the docker daemon
    assert_script_run "systemctl start docker", 200;

    # pull the alpine image
    # increase timeout, on systems using devicemapper as storage backend docker's initialization can take some time
    assert_script_run "docker pull alpine", 300;

    # make sure we can actually start a container
    script_run "docker run --rm alpine echo 'hello_from_container' > /dev/$serialdev", 0;
    die "cannot start container" unless wait_serial "hello_from_container", 200;

    # make sure we can actually start a container
    script_run "docker run --rm alpine wget http://google.com && echo 'container_network_works' > /dev/$serialdev", 0;
    die "network does not work inside of the container" unless wait_serial "container_network_works", 200;
}

1;
# vim: set sw=4 et:
