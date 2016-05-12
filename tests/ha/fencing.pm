# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self = shift;
    $self->barrier_wait("BEFORE_FENCING");
    if ($self->is_node1) {
        reset_consoles;
    }
    else {
        type_string "crm -F node fence " . get_var("HACLUSTERJOIN") . "; echo node_fence=\$? > /dev/$serialdev\n";
        die "fencing node failed" unless wait_serial "node_fence=0", 60;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
