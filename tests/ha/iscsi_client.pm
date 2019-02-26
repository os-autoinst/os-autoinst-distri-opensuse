# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure iSCSI target for HA tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use utils 'zypper_call';
use testapi;
use hacluster;

sub run {
    # Installation of iSCSI client package(s) if needed
    zypper_call 'in yast2-iscsi-client';

    # Configuration of iSCSI client
    script_run("yast2 iscsi-client; echo yast2-iscsi-client-status-\$? > /dev/$serialdev", 0);
    assert_screen 'iscsi-client-overview-service-tab';
    send_key 'alt-b';    # Start iscsi daemon on Boot
    wait_still_screen 3;
    send_key 'alt-i';    # Initiator name
    wait_still_screen 3;
    for (1 .. 40) { send_key 'backspace'; }
    type_string 'iqn.1996-04.de.suse:01:' . get_hostname . '.' . get_cluster_name;
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
    wait_screen_change { send_key 'alt-s' };    # Startup
    send_key 'down';
    wait_still_screen 3;
    send_key 'down';                            # Select 'automatic'
    assert_screen 'iscsi-client-target-startup-automatic-selected';
    send_key 'ret';
    wait_still_screen 3;
    send_key 'alt-n';                           # Next

    # Go to Discovered Targets screen can take time
    assert_screen 'iscsi-client-target-connected', 120;
    send_key 'alt-o';                           # Ok
    wait_still_screen 3;
    wait_serial('yast2-iscsi-client-status-0', 90) || die "'yast2 iscsi-client' didn't finish";

    # iSCSI LUN must be present
    assert_script_run 'ls -1 /dev/disk/by-path/ip-*-lun-*';
}

1;
