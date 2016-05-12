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
    $self->barrier_wait("FENCING_DONE");
    select_console 'root-console';

    script_run "hb_report -f 2014 hb_report", 120;
    upload_logs "hb_report.tar.bz2";
    type_string "echo segfaults=`grep -sR segfault /var/log | wc -l` > /dev/$serialdev\n";
    die "segfault occured" unless wait_serial "segfaults=0", 60;
    $self->barrier_wait("LOGS_CHECKED");
    if ($self->is_node1) {    #node1
        mutex_unlock("MUTEX_HA_" . get_var("CLUSTERNAME") . "_FINISHED");    # release support_server
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
