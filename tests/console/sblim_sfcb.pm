# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test if sfcbd has been migrated properly during the
#          upgrade and still starts
# Maintainer: Adam Majer <amajer@suse.de>

use base "consoletest";
use strict;
use testapi;

sub run() {
    assert_script_run 'rpm -qi sblim-sfcb';
    assert_script_run 'systemctl start sblim-sfcb.service';
    # FIXME: check if this service actually works, but this will do for now
    sleep 10;
    if (script_run('systemctl status sblim-sfcb.service | grep "Failed to load"') == 0) {
        record_soft_failure('Migration went wrong and services were not unregistered - bnc#1041885');
    }
    assert_script_run 'systemctl status sblim-sfcb.service';
    assert_script_run 'systemctl show -p ActiveState sblim-sfcb.service | grep ActiveState=active';
}
1;
