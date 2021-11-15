# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for container tests
# Maintainer: qac team <qa-c@suse.de>

package containers::basetest;
use containers::docker;
use containers::podman;
use Mojo::Base 'opensusebasetest';
use testapi 'get_var';

sub containers_factory {
    my ($self, $runtime) = @_;
    my $engine;

    if ($runtime eq 'docker') {
        $engine = containers::docker->new();
    }
    elsif ($runtime eq 'podman') {
        $engine = containers::podman->new();
    }
    else {
        die("Unknown runtime $runtime. Only 'docker' and 'podman' are allowed.");
    }
    $engine->init();
    return $engine;
}

sub test_flags {
    return get_var('PUBLIC_CLOUD') ? {no_rollback => 1} : {};
}

1;
