# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base 'opensusebasetest';
use testapi;
use qam;

use strict;
use warnings;

sub run() {
    my $self  = shift;
    my $svirt = select_console('svirt');
    my $name  = get_var('VIRSH_GUESTNAME');
    $svirt->attach_to_running($name);
    reset_consoles;
    select_console('sut');
    select_console('root-console');

    # full LTP, #TODO --> look at qa_automation , rework  qa_run.pm to library
    script_run("rm -Rf /var/log/qa", 120);


    script_run(qq{/usr/lib/ctcs2/tools/test_ltp-run; echo "ltp-done" > /dev/$serialdev}, 0);
    wait_serial(qr/ltp-done/, 36000);
    save_screenshot;

    $svirt->run_cmd("virsh reset $name");

}

sub post_fail_hook() {
    my $self            = shift;
    my $snapshot_before = get_var('KGRAFT_SNAPSHOT_BEFORE');
    my $name            = get_var('VIRSH_GUESTNAME');
    save_screenshot;
    send_key('ctrl-c');
    sleep 2;
    capture_state("fail");

    # reattach to svirt console and revert to snapshot before update
    my $svirt = select_console('svirt');
    $svirt->attach_to_running($name);
    snap_revert($svirt, $name, $snapshot_before);
}

sub test_flags() {
    return {fatal => 1};
}

1;
