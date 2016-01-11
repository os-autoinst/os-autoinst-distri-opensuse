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
    type_string "exit\n";
    type_string "firefox https://10.0.2.16:7630/\n";
    assert_and_click 'firefox-understand-risks';
    sleep 5;
    send_key 'f11';
    sleep 5;
    #assert_and_click 'firefox-add-exception';
    send_key 'tab';
    send_key 'ret';
    #assert_and_click 'firefox-confirm-exception';
    send_key 'alt-c';
    assert_screen 'hawk-login';
    assert_and_click 'hawk-username';
    type_string 'hacluster';
    send_key 'tab';
    type_string "linux\n";
    assert_screen 'firefox-remember-password';
    assert_and_click 'firefox-ignore-password';
    assert_screen 'hawk-dashboard';
}

1;
