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
# we make snapper rollback and  go back to downgraded system, (1)
# and we make another rollback for return back to upgraded system. At the end we have 6 snapshots.
# we are in a read_only_snapshot 1 and after we are in a read_and_write (2)
# cleanup the 4 created Snapshots  at the end of test (3)

# SNAPSHOT LISTS:
#
# 1 Before Migration Snapshot
# 2 After Migration Snapshot

# Rollback created snapshots, this snaps, will be cleanedu ups
# 3 R_Only Snapshot, cloned from 2  def. subvolume
# 4 R_write Snapshot, cloned from 1
# 5 R_Only Snapshot, cloned from 1,  default subvolume
# 6 R_write Snapshot, cloned from 2


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

    # Snapshot  4 == 1 Snapshoot
    # After normal_booting in 4 there is login stuff that differs from 1.
    script_run("snapper diff 1..4 >/dev/$serialdev; snapper status 1..4>/dev/$serialdev", 0);
    script_run("echo \"SNAPSHOT_1&4_IDENTICAL\" >/dev/$serialdev",                        0);
    wait_serial('^SNAPSHOT_1&4_IDENTICAL') || die "snapshot 1 != snap 4 EXPECTED: 1 == 4";

    save_screenshot;
    script_run("snapper diff 2..3 ", 0);
    # we are booting to snapshot 4, so status should differ now.
    script_run("systemctl reboot", 0);
    reset_consoles;
    wait_boot;
    select_console('root-console');

    script_run("snapper status 1..4");
    # *** (2) ****
    script_run("snapper rollback -d rollback-after-migration 2", 0);
    # EXPECT:  2 == 6. if 2 !=6 test fail, because it take more then 30 seconds to print the whole diff.
    assert_script_run("snapper status 2..6");
    assert_script_run("snapper diff 2..6");
    # (3) Cleanup. Delete snapshots
    assert_script_run("for i in {3..6};do snapper delete \$i;done; snapper list");
    save_screenshot;
    # (4) reboot into normal migrated systems.
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

