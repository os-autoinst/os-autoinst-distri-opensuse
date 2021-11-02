# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for container tests
# Maintainer: qac team <qa-c@suse.de>

package containers::basetest;
use Mojo::Base 'opensusebasetest';

sub containers_factory {
    my ($self, $runtime) = @_;
    my $engine;

    if ($runtime eq 'docker') {
        $engine = containers::engine::docker->new();
    }
    elsif ($runtime eq 'podman') {
        $engine = containers::engine::podman->new();
    }
    else {
        die("Unknown runtime $runtime. Only 'docker' and 'podman' are allowed.");
    }

    return $engine;
}

1;
