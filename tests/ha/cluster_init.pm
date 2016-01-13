# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use testapi;
use utils;
use autotest;

sub run() {
    send_key 'shift-ctrl-alt-g';
    type_string "ha-cluster-init -y -s /dev/disk/by-id/scsi-1LIO-ORG.FILEIO:348cfd84-58a1-426e-9797-e22f04cf207f\n";
    assert_screen 'cluster-init', 60;
    type_string "crm status\n";
    assert_screen 'cluster-status';
    clear_console;
}

1;
