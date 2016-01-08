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
    type_string "yast iscsi-client\n";
    assert_screen 'yast-iscsi-client-loaded';
    send_key 'alt-b';
    send_key 'alt-v';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-d';
    assert_screen 'yast-iscsi-initiator-discovery';
    send_key 'alt-i';
    sleep 1;
    type_string '10.162.2.65';
    sleep 1;
    send_key 'alt-n';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-l';
    assert_screen 'yast-iscsi-initiator-login';
    send_key 'alt-s';
    sleep 1;
    send_key 'down';
    sleep 1;
    send_key 'down';
    sleep 1;
    send_key 'ret';
    sleep 1;
    send_key 'alt-n';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-o';
}

1;
