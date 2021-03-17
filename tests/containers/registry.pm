# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: docker-distribution-registry
# Summary: Test container registry package
# - docker-distribution-registry package can be installed
# - docker-distribution-registry daemon can be started
# - images can be pushed
# - images can be searched
# - images can be pulled
# - images can be deleted
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils qw(is_sle is_tumbleweed is_leap get_os_release);
use registration;
use containers::common;
use containers::utils;

sub registry_push_pull {
    my ($runtime, %args) = @_;
    my $image = $args{image};

    die 'Argument $image not provided!' unless $image;

    # Pull $image
    $runtime->_rt_assert_script_run("pull $image",            timeout => 600);
    $runtime->_rt_assert_script_run("images | grep '$image'", timeout => 60);

    # Tag $image for the local registry
    $runtime->_rt_assert_script_run("tag $image localhost:5000/$image",      timeout => 90);
    $runtime->_rt_assert_script_run("images | grep 'localhost:5000/$image'", timeout => 60);

    # Push $image to the local registry
    $runtime->_rt_assert_script_run("push localhost:5000/$image", timeout => 90);

    # Remove $image as well as the local registry $image
    # The localhost:5000/$image must be removed first
    $runtime->_rt_assert_script_run("image rm -f localhost:5000/$image", timeout => 90);
    $runtime->_rt_assert_script_run("image rm -f $image",                timeout => 90);
    assert_script_run("! " . $runtime->engine . " images | grep '$image'",         timeout => 60);
    assert_script_run("! " . $runtime->engine . " | grep 'localhost:5000/$image'", timeout => 60);

    # Pull $image from the local registry
    $runtime->_rt_assert_script_run("pull localhost:5000/$image",            timeout => 90);
    $runtime->_rt_assert_script_run("images | grep 'localhost:5000/$image'", timeout => 60);
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();
    my ($running_version, $sp, $host_distri) = get_os_release();
    my $docker = containers::runtime->new(engine => 'docker');

    # Package Hub is not enabled on 15-SP3 yet.
    return if is_sle '=15-SP3';

    # Install and check that it's running
    add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1) if is_sle(">=15");
    zypper_call 'se -v docker-distribution-registry';
    zypper_call 'in docker-distribution-registry';
    systemctl '--now enable registry';
    systemctl 'status registry';

    script_retry 'curl http://127.0.0.1:5000/v2/_catalog', delay => 3, retry => 10;
    assert_script_run 'curl -s http://127.0.0.1:5000/v2/_catalog | grep repositories';

    # Run docker tests
    install_docker_when_needed($host_distri);
    allow_selected_insecure_registries($docker);
    my $tumbleweed = 'registry.opensuse.org/opensuse/tumbleweed';
    registry_push_pull($docker, image => $tumbleweed);
    $docker->cleanup_system_host();

    # Run podman tests
    if (is_leap('15.1+') || is_tumbleweed() || is_sle("15-sp1+")) {
        my $podman = containers::runtime->new(engine => 'podman');
        install_podman_when_needed($host_distri);
        allow_selected_insecure_registries($podman);
        registry_push_pull($podman, image => $tumbleweed);
        $podman->cleanup_system_host();
    }
}

1;
