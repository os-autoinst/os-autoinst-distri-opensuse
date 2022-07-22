# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper-docker
# Summary: Test zypper-docker installation and its usage
#    Cover the following aspects of zypper-docker:
#      * zypper-docker package can be installed
#      * zypper-docker can list local images:                    'zypper-docker images ls'
#      * zypper-docker can list updates/patches:                 'zypper-docker list-updates' 'zypper-docker list-patches'
#      * zypper-docker can list outdated containers:             'zypper-docker ps'
#      * zypper-docker can list updates/patches for a container: 'zypper-docker list-updates-container' 'zypper-docker list-patches-container'
#      * zypper-docker can apply the updates:                    'zypper-docker update'
# Maintainer: Antonio Caristia <acaristia@suse.com>

use Mojo::Base 'containers::basetest';
use testapi;
use Utils::Architectures;
use utils;
use containers::common;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $docker = $self->containers_factory('docker');
    record_info("INFO", "Dummy change");
    # install zypper-docker and verify installation
    zypper_call('in zypper-docker');
    validate_script_output("zypper-docker -h", sub { m/zypper-docker - Patching Docker images safely/ }, 180);
    my $testing_image = 'registry.opensuse.org/opensuse/leap';

    # pull image and check zypper-docker's images funcionalities
    assert_script_run("docker image pull $testing_image", timeout => 600);
    my $local_images_list = script_output('docker images');
    die("docker image $testing_image not found") unless ($local_images_list =~ /opensuse\s*/);
    validate_script_output("zypper-docker images ls", sub { m/opensuse/ }, 180);
    script_retry("zypper-docker list-updates $testing_image", timeout => 600, retry => 5, delay => 60);
    script_retry("zypper-docker list-patches $testing_image", timeout => 600, retry => 5, delay => 60);
    # run a container and check zypper-docker's containers funcionalities
    assert_script_run("docker container run -d --name tmp_container $testing_image tail -f /dev/null");
    assert_script_run("zypper-docker ps", timeout => 600);
    script_retry("zypper-docker list-updates-container tmp_container", timeout => 600, retry => 5, delay => 60);
    script_retry("zypper-docker list-patches-container tmp_container", timeout => 600, retry => 5, delay => 60);
    # apply all the updates to a new_image
    script_retry("zypper-docker update --auto-agree-with-licenses $testing_image new_image", timeout => 900, retry => 5, delay => 60);
    $docker->cleanup_system_host();
}

1;
