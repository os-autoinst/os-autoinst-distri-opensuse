# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Clone system and use the autoyast file in chained tests
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "console_yasttest";
use strict;
use testapi;
use utils 'zypper_call';

sub run() {
    select_console 'root-console';

    # Install for TW and generate profile
    zypper_call "in autoyast2";
    script_run("yast2 clone_system; echo yast2-clone-system-status-\$? > /dev/$serialdev", 0);

    # workaround for bsc#1013605
    assert_screen([qw(dhcp-popup yast2_console-finished)], 200);
    if (match_has_tag('dhcp-popup')) {
        wait_screen_change { send_key 'alt-o' };
        assert_screen 'yast2_console-finished', 200;
    }
    wait_serial('yast2-clone-system-status-0') || die "'yast2 clone_system' didn't finish";

    # Replace unitialized email variable - bsc#1015158
    assert_script_run 'sed -i "/server_email/ s/postmaster@/\0suse.com/" /root/autoinst.xml';

    # Check and upload profile for chained tests
    upload_asset "/root/autoinst.xml";
    if (script_run 'xmllint --noout --relaxng /usr/share/YaST2/schema/autoyast/rng/profile.rng /root/autoinst.xml') {
        record_soft_failure 'bsc#1013047';
    }

    # Remove for autoyast_removed test - poo#11442
    assert_script_run "rm /root/autoinst.xml";
}

1;
# vim: set sw=4 et:
