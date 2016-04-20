# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# *** TEST DESCRIPTION : ****
# test a rollback (as a backup) situation after system has migrated. (e.g from Sles12 to sp2)
# we make snapper rollback and  go back to downgraded system,

use base "consoletest";
use testapi;
use utils;

sub run() {

    # assert the we are on a ro snapshot.
    assert_screen 'linux-login', 200;
    select_console 'root-console';
    # 1)
    script_run('touch NOWRITE;test ! -f NOWRITE', 0);
    # 1b) just debugging infos
    script_run("snapper list",        0);
    script_run("cat /etc/os-release", 0);
    # rollback
    script_run("snapper rollback -d rollback-before-migration");
    assert_script_run("snapper list | tail -n 2 | grep rollback");
    script_run("systemctl reboot", 0);
    reset_consoles;
    wait_boot;
    select_console 'root-console';
}
sub test_flags() {
    return {fatal => 1};

}
1;
# vim: set sw=4 et:
