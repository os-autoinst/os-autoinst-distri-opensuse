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
use lockapi;

sub run() {
    if (get_var('WORKER_CLASS') =~ /ha_master/) {
        type_string "sleha-init -y -s /dev/disk/by-id/scsi-1LIO-ORG.FILEIO:348cfd84-58a1-426e-9797-e22f04cf207f\n";
        assert_screen 'cluster-init', 60;
        type_string "crm status\n";
        assert_screen 'cluster-status';
        clear_console;
        mutex_create('cluster-init');
    }
    else {
        mutex_unlock('cluster-init');
        type_string "sleha-join -y -c 10.0.2.16\n";
        assert_screen 'cluster-join-password';
        type_string "nots3cr3t\n";
        if (!check_screen('cluster-join-finished', 60)) {
            type_string "hb_report -f 00:00 hbreport\n";
            upload_logs "/root/hbreport.tar.bz2";
            type_string "tailf /var/log/messages\n";    # Probably redundant, remove if not needed
            save_screenshot();
        }
        type_string "crm status\n";
        if (!check_screen('cluster-status')) {
            type_string "hb_report -f 00:00 hbreport\n";
            upload_logs "/root/hbreport.tar.bz2";
            type_string "tailf /var/log/messages\n";    # Probably redundant, remove if not needed
            save_screenshot();
        }
        clear_console;
    }
}

1;
