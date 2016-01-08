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
use autotest;

sub joincluster() {
    type_string "ha-cluster-join -y -c 10.0.2.16\n";
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
        save_screenshot();
    }
    send_key 'ctrl-l';
}

sub run() {
    send_key 'ctrl-pgdn';
    for my $i (1 .. 2) {
        joincluster();
        send_key 'ctrl-pgdn';
    }
}

1;
