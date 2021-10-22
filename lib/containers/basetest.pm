# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Factory design pattern for container engines.
# Maintainer: qac team <qa-c@suse.de>

package containers::basetest;
use Mojo::Base 'consoletest';
use testapi;
use containers::engine;

has runtime_instance => undef;

sub get_instance {
    my ($self, $runargs) = @_;
    if (!keys %{$runargs}) {
        # Hack for the jobs that use yaml scheduler
        # We have move to main_*.pm in most of the cases but there is one or two which uses yaml.
        # This will not work if the module used in the same job twice for both docker and podman
        check_var('CONTAINER_RUNTIME', 'docker') ? $runargs->{docker} = 1 : $runargs->{podman} = 1;
    }
    if (defined $runargs->{docker}) {
        $self->runtime_instance(containers::engine::docker->new());
    }
    elsif (defined $runargs->{podman}) {
        $self->runtime_instance(containers::engine::podman->new());
    }
    else {
        die 'job doesnt provide Runtime Container tool';
    }
    return $self->runtime_instance;
}

1;
