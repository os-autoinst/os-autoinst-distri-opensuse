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
use testapi;
use Utils::Logging qw(record_avc_selinux_alerts);

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

sub post_fail_hook {
    my ($self) = @_;
    # post_{fail|run}_hooks are not working with 3rd party hosts
    return if get_var('NOLOGS');

    select_console('log-console');

    $self->record_avc_selinux_alerts;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    # post_{fail|run}_hooks are not working with 3rd party hosts
    return if get_var('NOLOGS');

    shift->record_avc_selinux_alerts;
}

1;
