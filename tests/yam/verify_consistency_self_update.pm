# Copyright 2024 SUSE LLC
#
# Summary: Update the system using the specified repo and then
#          open and close YaST2 control center using both Qt and Ncurses interfaces.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;
use y2_module_guitest;
use y2_module_consoletest;

sub run {
    select_console 'root-console';

    zypper_call 'ar -f ' . get_var('SELF_UPDATE_REPO') . ' self-update-repo';
    zypper_call 'dup';
    zypper_call 'lr --uri';

    y2_module_consoletest::yast2_console_exec(yast2_module => '', match_timeout => 180);
    assert_screen 'yast2-control-center-ncurses';
    wait_screen_change { send_key 'alt-q'; };

    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('', target_match => 'yast2-control-center-ui', match_timeout => 180);
    wait_screen_change { send_key 'alt-f4'; };

    select_console 'root-console';
}

1;
