# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#  this test test the read-only snapshot, from console. (1)
#  we print some console output only for nice debugging (1b)
#  if variable UPGRADE is set, we want to check that the 2 snapshots
#  before_upgrade and after upgrade are not identical. test is made
#  by checking the /etc/os-release, this is compatible also for openSUSE-TW (2)

use strict;
use testapi;

sub run() {
    my $self = shift;
    wait_idle;
    wait_still_screen;
    select_console 'root-console';

    # 1) test property read_only snapshot
    assert_script_run('touch NOWRITE;test ! -f NOWRITE') || die "bootable snapshot was read only! Snapshot may be WRITTEN!";
    # 1b) just debugging infos
    assert_script_run("snapper list");

    # 2) we want to test a backup situation, so we are here on before_update snapshot.
    # we have 2 snapshots, we are in the first one, before migration.
    if (get_var("UPGRADE")) {
        # extract number of version id: example SlES 12.2 -> 12.2 . this work for opensuse also
        my $OS_VERSION     = script_output("grep VERSION_ID /etc/os-release | cut -c13- | head -c -2");
        my $OLD_OS_VERSION = script_output("grep VERSION_ID /.snapshots/2/snapshot/etc/os-release | cut -c13- | head -c -2");

        if ($OS_VERSION eq $OLD_OS_VERSION) {
            die "something went wrong on migrtion; snapshot before upgrade $OS_VERSION, has some VERSION name that differ frm AFTER_MIGRATION:$OLD_OS_VERSION";
        }
        return;
    }
    else {
        script_run("systemctl reboot");
    }
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
