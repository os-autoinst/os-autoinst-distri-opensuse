# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure simple ncurses applications can start and look correct
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(clear_console zypper_call);

sub run {
    select_console 'root-console';
    zypper_call 'in dialog';
    script_run 'dialog --yesno "test for boo#1054448" 3 20', 0;
    assert_screen 'ncurses-simple-dialog';
    send_key 'ret';
    clear_console;
    if (match_has_tag 'boo#1054448') {
        record_soft_failure 'boo#1054448';
        my $cmd = 'export TERM=linux';
        assert_script_run "$cmd && echo '$cmd' > /etc/profile";
        select_console 'user-console';
        assert_script_run "$cmd";
        select_console 'root-console';
    }
}

1;
