# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure iSCSI target for HA tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;

sub run {
    my $self = shift;

    # Configuration of iSCSI client
    script_run("yast2 iscsi-client; echo yast2-iscsi-client-status-\$? > /dev/$serialdev", 0);
    assert_screen 'iscsi-client-overview-service-tab';
    send_key 'alt-b';    # Start iscsi daemon on Boot
    wait_still_screen 3;
    send_key 'alt-i';    # Initiator name
    wait_still_screen 3;
    for (1 .. 40) { send_key 'backspace'; }
    type_string 'iqn.1996-04.de.suse:01:' . get_var('HOSTNAME') . '.' . get_var('CLUSTER_NAME');
    wait_still_screen 3;
    send_key 'alt-v';    # discoVered targets
    wait_still_screen 3;

    # Go to Discovered Targets screen can take time
    assert_screen 'iscsi-client-discovered-targets', 120;
    send_key 'alt-d';    # Discovery
    wait_still_screen 3;
    assert_screen 'iscsi-client-discovery';
    send_key 'alt-i';    # Ip address
    wait_still_screen 3;
    type_string 'ns';
    wait_still_screen 3;
    send_key 'alt-n';    # Next

    # Select target with internal IP first?
    assert_screen 'iscsi-client-target-list';
    send_key 'alt-e';    # connEct
    assert_screen 'iscsi-client-target-startup';
    send_key 'alt-s';    # Startup
    wait_still_screen 3;
    send_key 'down';
    wait_still_screen 3;
    send_key 'down';     # Select 'automatic'
    assert_screen 'iscsi-client-target-startup-automatic-selected';
    send_key 'ret';
    wait_still_screen 3;
    send_key 'alt-n';    # Next

    # Go to Discovered Targets screen can take time
    assert_screen 'iscsi-client-target-connected', 120;
    send_key 'alt-o';    # Ok
    wait_still_screen 3;
    wait_serial('yast2-iscsi-client-status-0', 90) || die "'yast2 iscsi-client' didn't finish";

    # iSCSI LUN must be present
    $self->clear_and_verify_console;
    assert_script_run 'ls -1 /dev/disk/by-path/ip-*-lun-*';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
