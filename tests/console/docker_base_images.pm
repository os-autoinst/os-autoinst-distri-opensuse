# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Pull and test several base images for their functionality
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use containers::common;

# Test a given image. Takes the docker image name and version as argument
sub test_image {
    my $name    = $_[0];
    my $version = $_[1] //= "latest";
    # Pull the image
    my $image = "$name:$version";
    assert_script_run("docker image pull $image", timeout => 300);
    assert_script_run("docker image ls | grep '$name' | grep '$version'");

    my $container = "${name}_${version}_smoketest";
    $container =~ s!/!.!g;    # Slashes are not allowed as container names, but used for fetching images. Replace them with a dot
    my $smoketest = "/bin/uname -r; /bin/echo \"Heartbeat from $image\"";
    assert_script_run("docker container create --name '$container' '$image' /bin/sh -c '$smoketest'");
    assert_script_run("docker container start '$container'");
    assert_script_run("docker container logs '$container' > '/var/tmp/container_$container'");
    assert_script_run("docker container rm '$container'");
    assert_script_run("grep \"`uname -r`\" '/var/tmp/container_$container'");
    assert_script_run("grep \"Heartbeat from $image\" '/var/tmp/container_$container'");
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    install_docker_when_needed();
    # Test base images
    test_image('alpine',              'latest');
    test_image('opensuse/leap',       'latest');
    test_image('opensuse/tumbleweed', 'latest');
    test_image('debian',              'latest');
    test_image('ubuntu',              'latest');
    test_image('centos',              'latest');
    test_image('fedora',              'latest');
    clean_docker_host();
}

1;
