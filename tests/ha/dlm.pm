# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure DLM in cluster configuration
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self = shift;
    barrier_wait("DLM_INIT_" . $self->cluster_name);
    type_string "rpm -q dlm-kmp-default; echo dlm_kmp_default_installed=\$? > /dev/$serialdev\n";
    if ($self->is_node1) {    #node1
        type_string "echo wait until DLM resource is created\n";
    }
    else {
        type_string
qq(EDITOR="sed -ie '\$ a primitive dlm ocf:pacemaker:controld op monitor interval=60 timeout=60'" crm configure edit; echo dlm_add=\$? > /dev/$serialdev\n);
        die "create DLM resource failed" unless wait_serial "dlm_add=0", 60;
        type_string
qq(EDITOR="sed -ie '\$ a group base-group dlm'" crm configure edit; echo base_group_add=\$? > /dev/$serialdev\n);
        die "create base-group failed" unless wait_serial "base_group_add=0", 60;
        type_string
qq(EDITOR="sed -ie '\$ a clone base-clone base-group'" crm configure edit; echo base_clone_add=\$? > /dev/$serialdev\n);
        die "create base-clone failed" unless wait_serial "base_clone_add=0", 60;
    }
    barrier_wait("DLM_GROUPS_CREATED_" . $self->cluster_name);
    type_string "ps -A | grep -q dlm_controld; echo dlm_running=\$? > /dev/$serialdev\n";
    die "dlm_controld is not running" unless wait_serial "dlm_running=0", 60;
    barrier_wait("DLM_CHECKED_" . $self->cluster_name);
}

1;
