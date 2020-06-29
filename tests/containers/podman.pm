# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
# Maintainer: Richard Brown <rbrown@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use registration;
use containers::common;
use version_utils qw(is_sle is_leap is_jeos);
use containers::utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $dir = "/root/DockerTest";

    install_podman_when_needed();

    # Run basic tests for podman
    basic_container_tests("podman");

    # Setup the environment
    set_up("$dir");

    # Build the image
    build_img("$dir", "podman");

    # Run the built image
    test_built_img("podman");

    # Clean container
    clean_container_host(runtime => "podman");
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    script_run "podman version | tee /dev/$serialdev";
    script_run "podman info --debug | tee /dev/$serialdev";
    $self->SUPER::post_fail_hook;
}

1;
