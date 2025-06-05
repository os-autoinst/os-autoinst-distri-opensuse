# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for container tests
# Maintainer: qac team <qa-c@suse.de>

package containers::basetest;
use strict;
use warnings;
use containers::docker;
use containers::podman;
use containers::containerd_crictl;
use containers::containerd_nerdctl;
use Mojo::Base 'opensusebasetest';

sub containers_factory {
    my ($self, $runtime) = @_;
    my $engine;

    if ($runtime eq 'docker') {
        $engine = containers::docker->new();
    }
    elsif ($runtime eq 'podman') {
        $engine = containers::podman->new();
    }
    elsif ($runtime eq 'containerd_crictl') {
        $engine = containers::containerd_crictl->new();
    }
    elsif ($runtime eq 'containerd_nerdctl') {
        $engine = containers::containerd_nerdctl->new();
    }
    else {
        die("Unknown runtime '$runtime'.");
    }
    $engine->init();
    return $engine;
}

1;
