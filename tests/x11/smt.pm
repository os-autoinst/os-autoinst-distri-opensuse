# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add smt configuration test
#    test installation and upgrade with smt pattern, basic configuration via
#    smt-wizard and validation with smt-repos smt-sync return value
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run() {
    x11_start_program("xterm -geometry 150x35+5+5");
    assert_screen('xterm-started');
    become_root;
    if (!get_var("UPGRADE")) {
        type_string "yast2 smt-wizard;echo yast2-smt-wizard-\$? > /dev/$serialdev\n";
        assert_screen 'smt-wizard-1';
        send_key 'alt-u';
        wait_still_screen;
        type_string 'SCC_ORG_DAJJBA';
        send_key 'alt-p';
        wait_still_screen;
        type_string '043107d3db';
        send_key 'alt-n';
        assert_screen 'smt-wizard-2';
        send_key 'alt-d';
        wait_still_screen;
        type_password;
        send_key 'tab';
        type_password;
        send_key 'alt-n';
        assert_screen 'smt-mariadb-password', 60;
        type_password;
        send_key 'tab';
        type_password;
        send_key 'alt-o';
        assert_screen 'smt-server-cert';
        send_key 'alt-r';
        assert_screen 'smt-CA-password';
        send_key 'alt-p';
        wait_still_screen;
        type_password;
        send_key 'tab';
        type_password;
        send_key 'alt-o';
        assert_screen 'smt-installation-overview';
        send_key 'alt-n';
        wait_serial("yast2-smt-wizard-0", 200) || die 'smt wizard failed';
    }
    assert_script_run 'smt-sync', 600;
    assert_script_run 'smt-repos';
    type_string "killall xterm\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
