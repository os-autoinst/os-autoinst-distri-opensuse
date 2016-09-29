# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

sub cluster_name {
    return get_var("CLUSTERNAME");
}

sub post_run_hook {
    my ($self) = @_;
    # clear screen to make screen content ready for next test
    #    $self->clear_and_verify_console;
}

1;
# vim: set sw=4 et:
