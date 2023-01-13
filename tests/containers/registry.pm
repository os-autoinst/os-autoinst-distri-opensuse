# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker-distribution-registry | distribution-registry
# Summary: Test container registry package
# - distribution-registry package can be installed
# - distribution-registry daemon can be started
# - images can be pushed
# - images can be searched
# - images can be pulled
# - images can be deleted
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_tumbleweed is_leap);
use registration;
use containers::common;
use containers::utils;

sub registry_push_pull {
    my %args = @_;
    my $image = $args{image};
    my $engine = $args{runtime};

    die 'Argument $image not provided!' unless $image;
    die 'Argument $engine not provided!' unless $engine;

    # Pull $image
    assert_script_run $engine->runtime . " pull $image", 600;
    assert_script_run $engine->runtime . " images | grep '$image'", 60;

    # Tag $image for the local registry
    assert_script_run $engine->runtime . " tag $image localhost:5000/$image", 90;
    assert_script_run $engine->runtime . " images | grep 'localhost:5000/$image'", 60;

    # Push $image to the local registry
    assert_script_run $engine->runtime . " push localhost:5000/$image", 90;

    # Remove $image as well as the local registry $image
    # The localhost:5000/$image must be removed first
    assert_script_run $engine->runtime . " image rm -f localhost:5000/$image", 90;
    if (script_run($engine->runtime . " images | grep '$image'") == 0) {
        assert_script_run $engine->runtime . " image rm -f $image", 90;
    } else {
        record_soft_failure("Known issue - containers/podman#10685: podman image rm --force also untags other images (3.2.0 regression)");
    }
    assert_script_run "! " . $engine->runtime . " images | grep '$image'", 60;
    assert_script_run "! " . $engine->runtime . " images | grep 'localhost:5000/$image'", 60;

    # Pull $image from the local registry
    assert_script_run $engine->runtime . " pull localhost:5000/$image", 90;
    assert_script_run $engine->runtime . " images | grep 'localhost:5000/$image'", 60;
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Install and check that it's running
    my $pkg = 'distribution-registry';
    if (is_sle(">=15-SP4")) {
        activate_containers_module;
    } elsif (is_sle("<=15")) {
        record_info("SKIP", "docker-distribution-registry is not available on this version of SLE");
        return;
    } elsif (is_sle(">15")) {
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
        $pkg = 'docker-distribution-registry';
    } elsif (is_leap("<15.4")) {
        $pkg = 'docker-distribution-registry';
    }

    zypper_call "se -v $pkg";
    zypper_call "in $pkg";
    systemctl '--now enable registry';
    systemctl 'status registry';

    script_retry 'curl http://127.0.0.1:5000/v2/_catalog', delay => 3, retry => 10;
    assert_script_run 'curl -s http://127.0.0.1:5000/v2/_catalog | grep repositories';

    # Run docker tests
    my $docker = $self->containers_factory('docker');
    my $tumbleweed = 'registry.opensuse.org/opensuse/tumbleweed';
    registry_push_pull(image => $tumbleweed, runtime => $docker);
    $docker->cleanup_system_host();

    # Run podman tests
    if (is_leap('15.1+') || is_tumbleweed || is_sle("15-sp1+")) {
        my $podman = $self->containers_factory('podman');
        registry_push_pull(image => $tumbleweed, runtime => $podman);
        $podman->cleanup_system_host();
    }
}

1;
