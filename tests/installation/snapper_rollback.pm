# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# *** TEST DESCRIPTION : ****
# test a rollback (as a backup) situation after system has migrated. (e.g from Sles12sp1 to sp2)
# we make snapper rollback and  go back to downgraded system, (1)
# and we make another rollback for return back to upgraded system. At the end we have 6 snapshots.
# we are in a read_only_snapshot 1 and after we are in a read_and_write (2)

# snapper rollback,  make 2 snapshots. From Manpage:
# Without a number, a first read-only snapshot of the default subvolume is created.:
# A second read-write snapshot of the current system is created.
# The system is set to boot from the second  snapshot.


use base "consoletest";
use testapi;
use utils;


sub run() {
    my $self = shift;
    #(1)
    script_run("snapper rollback -d rollback-before-migration");
    assert_script_run("snapper list | tail -n 2 | grep rollback");
    # booting into rollbacked snapshot.
    script_run("systemctl reboot", 0);
    reset_consoles;
    wait_boot;
    select_console('root-console');
    # *** (2) ****
    my $snap_after_migration = script_output("snapper list | grep 'after update' | cut -d'|' -f 2 | xargs");
    script_run("snapper rollback -d rollback-after-migration $snap_after_migration", 0);
    # reboot into normal migrated systems.
    script_run("systemctl reboot", 0);
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

sub test_flags() {
    return {fatal => 1};

}

1;
# vim: set sw=4 et:

