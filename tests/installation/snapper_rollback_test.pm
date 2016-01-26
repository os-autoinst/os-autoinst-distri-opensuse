# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# the test's goal is to test a rollback (as a backup) after system has migrated.
# we make one rollback to going back to downgraded system, (1)
# and we make another rollback to go to upgraded system. at the end 6 snapshots.
# we are in a read_only_snapshot 1 and after we are in a read_and_write 2


# TODO: make cleanup test, to remove the 4 created snapshots? inside or outside
#       testsuite?. to discuss.
use base "consoletest";
use testapi;
use utils;


sub run() {
    my $self = shift;
    #1) read only snapshot. Don't try to save something here.
    script_run("snapper rollback -d rollback-before-migration");

    assert_script_run("snapper list | tail -n 2 | grep rollback");

    # we are in the before migration version. So snapshot 4 is identical to
    # snapshot 1.
    # 1 before migration = 4 since we did not already booted on snapshot 4.
    # After normal_booting in 4 there is login stuff that differs from 1.
    script_run("echo \"SNAPSHOT_1&4_IDENTICAL\" >/dev/$serialdev", 0);
    script_run("snapper diff 1..4 >/dev/$serialdev",               0);
    script_run("snapper status 1..4>/dev/$serialdev",              0);
    # FIXME if test passed, $serialdev should be empty ( maybe to new lines \n?)
    wait_serial('^SNAPSHOT_1&4_IDENTICAL') || die "snapshots differ when they should have been identical";

    # we are booting to snapshot 4, so status should differ now.
    script_run("systemctl reboot");
    reset_consoles;
    wait_boot textmode => 0, bootloader => 5000;    # safe timeout
    select_console('root-console');

    script_run("snapper status 1..4");
    # *** 2) ****
    # here we are in the snapshot 4 again, but read and write. (before-migration)
    # we want to rollback or go to "after-migration" system:
    script_run("snapper rollback -d rollback-after-migration 2");
    # this test proves that we have 2 equal to 6 which was created right now by
    # snapper. If we boot, they should differ (minimaly)
    assert_script_run("snapper status 2..6");
    assert_script_run("snapper diff 2..6");
    # 4 reboot into normal (migrated configuration) for other tests
    script_run("systemctl reboot");
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
