# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test podman pods functionality
# - Use data/containers/hello-kubic.yaml to run pods
# - Confirm 3 pods are spawned
# - Clean up pods using hello-kubic.yaml
# Maintainer: Richard Brown <rbrown@suse.com>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $podman = $self->containers_factory('podman');

    record_info('Prep', 'Get kube yaml');
    assert_script_run("wget " . data_url("containers/hello-kubic.yaml") . " -O hello-kubic.yaml");

    record_info('Test', 'Create hello-kubic pod');
    assert_script_run('podman play kube hello-kubic.yaml');

    record_info('Test', 'Confirm pods are running');
    record_info('pod ps', script_output('podman pod ps'));
    assert_script_run('podman pod ps | grep "Running" | wc -l | grep -q 3');

    record_info('Cleanup', 'Stop pods');
    assert_script_run('podman play kube --down hello-kubic.yaml');
}

1;
