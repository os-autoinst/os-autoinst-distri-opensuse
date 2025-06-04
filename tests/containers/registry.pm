# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: registry
# Summary: Test container registry package
# - distribution-registry package can be installed
# - distribution-registry daemon can be started
# - images can be pushed
# - images can be searched
# - images can be pulled
# - images can be deleted
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_tumbleweed);
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
        die("rm --force untags other images");
    }
    assert_script_run "! " . $engine->runtime . " images | grep '$image'", 60;
    assert_script_run "! " . $engine->runtime . " images | grep 'localhost:5000/$image'", 60;

    # Pull $image from the local registry
    assert_script_run $engine->runtime . " pull localhost:5000/$image", 90;
    assert_script_run $engine->runtime . " images | grep 'localhost:5000/$image'", 60;

    # podman artifact needs podman 5.4.0
    if ($engine->runtime eq "podman" && (is_tumbleweed || is_sle('>=16.0'))) {
        my $artifact = "localhost:5000/testing-artifact";
        assert_script_run "podman artifact add $artifact /etc/passwd";
        assert_script_run "podman artifact push $artifact";
        assert_script_run "podman artifact rm $artifact";
        assert_script_run "podman artifact pull $artifact";
        assert_script_run "podman artifact rm $artifact";
    }
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $registry = 'registry.opensuse.org/opensuse/registry:latest';
    my $image = 'registry.opensuse.org/opensuse/busybox';

    foreach my $runtime ('docker', 'podman') {
        my $engine = $self->containers_factory($runtime);
        script_retry "$runtime pull $image", timeout => 300, delay => 60, retry => 3;
        assert_script_run "$runtime run -d --name registry --net=host -p 5000:5000";
        script_retry 'curl http://127.0.0.1:5000/v2/_catalog', delay => 3, retry => 10;
        assert_script_run 'curl -s http://127.0.0.1:5000/v2/_catalog | grep repositories';
        registry_push_pull(image => $image, runtime => $docker);
        script_run "$runtime rm -vf registry";
        $engine->cleanup_system_host();
    }
}

1;
