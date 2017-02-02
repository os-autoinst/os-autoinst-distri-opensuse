# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package kgrafttest;
use base "opensusebasetest";

use strict;
use testapi;
use qam;

sub post_fail_hook() {
    my $snapshot_before = get_var('KGRAFT_SNAPSHOT_BEFORE');
    my $name            = get_var('VIRSH_GUESTNAME');
    save_screenshot;
    send_key('ctrl-c');
    sleep 2;
    capture_state("fail");

    #reconnect to svirt backend and revert to snapshot before update
    my $svirt = select_console('svirt');
    $svirt->attach_to_running({name => $name});
    snap_revert($svirt, $name, $snapshot_before);
}

sub test_flags() {
    return {fatal => 1};
}

1;
