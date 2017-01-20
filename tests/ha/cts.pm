# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install pacemaker-cts on cluster nodes and wait until tests are done
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self = shift;
    assert_script_run "zypper -n in pacemaker-cts";
    type_string "exit\n";
    reset_consoles
      ;    #if the node is fenced during tests, next `select_console 'root-console'` will login as root in any case
    $self->barrier_wait("PACEMAKER_CTS_INSTALLED");
    if ($self->is_node1) {    #TODO: replace this ugly stuff with normal barriers
        mutex_unlock("MUTEX_CTS_INSTALLED");
        mutex_lock("MUTEX_CTS_FINISHED");    #support server finished cts
    }
    $self->barrier_wait("PACEMAKER_CTS_FINISHED");
}

sub test_flags {
    return {fatal => 1};
}

1;
