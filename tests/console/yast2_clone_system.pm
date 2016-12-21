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
    assert_script_run "yast2 clone_system", 200;

    # Replace unitialized email variable - bsc#1015158
    assert_script_run 'sed -i "/server_email/ s/postmaster@/\0suse.com/" /root/autoinst.xml';

    # Check and upload profile for chained tests
    upload_asset "/root/autoinst.xml";
    assert_script_run "xmllint --noout --relaxng /usr/share/YaST2/schema/autoyast/rng/profile.rng /root/autoinst.xml";

    # Remove for autoyast_removed test - poo#11442
    assert_script_run "rm /root/autoinst.xml";
}

1;
# vim: set sw=4 et:
