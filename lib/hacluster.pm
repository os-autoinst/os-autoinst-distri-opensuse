# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# temporary implementation of barrier_create and barrier_wait functions, they work only for two nodes (with HOSTNAME set to "host1" and "host2")

package hacluster;
use base "opensusebasetest";
use testapi;
use autotest;
use lockapi;
use strict;

sub is_node1 {
    return (get_var("HOSTNAME") eq "host1");
}

sub is_node2 {
    return (get_var("HOSTNAME") eq "host2");
}

sub barrier_wait {
    my $self         = shift;
    my $barrier_name = shift;
    if (is_node1) {
        mutex_unlock("MUTEX_${barrier_name}_M1");
        mutex_lock("MUTEX_${barrier_name}_M2");
    }
    if (is_node2) {
        mutex_unlock("MUTEX_${barrier_name}_M2");
        mutex_lock("MUTEX_${barrier_name}_M1");
    }
}

sub barrier_create {
    my $self         = shift;
    my $barrier_name = shift;
    if (is_node1) {    #mutex_create now moved to main.pm as workaround
        mutex_lock("MUTEX_${barrier_name}_M1");
    }
    if (is_node2) {
        #        mutex_create("MUTEX_${barrier_name}_M2");
        mutex_lock("MUTEX_${barrier_name}_M2");
    }
}

sub post_run_hook {
    my ($self) = @_;
    # clear screen to make screen content ready for next test
    #    $self->clear_and_verify_console;
}

1;
# vim: set sw=4 et:
