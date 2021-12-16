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

has engine => undef;
sub containers_factory {
    my ($self, $runargs) = @_;

    if (defined $runargs->{docker}) {
        $self->engine(containers::docker->new());
    }
    elsif (defined $runargs->{podman}) {
        $self->engine(containers::podman->new());
    }
    else {
        die("Unknown runtime $self->engine. Only 'docker' and 'podman' are allowed.");
    }
    $self->engine->init();
    return $self->engine;
}

1;
