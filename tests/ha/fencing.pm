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

sub run() {
    type_string "crm node fence node2\n";
    assert_screen 'cluster-really-shoot-q';
    type_string "y\n";
    sleep 15;
    type_string "crm status\n";
    assert_screen 'cluster-node-down';
    sleep 240;
    send_key 'ctrl-l';
    type_string "crm status\n";
    assert_screen 'cluster-node-returned';
    send_key 'ctrl-l';
    send_key 'ctrl-pgdn';
    send_key 'ret';
    type_string "ssh 10.0.2.17 -l root\n";
    sleep 10;
    type_string "nots3cr3t\n";
    sleep 10;
    send_key 'ctrl-l';
    type_string "crm status\n";
    assert_screen 'cluster-status';
    send_key 'ctrl-l';
    send_key 'ctrl-pgup';
}

1;
