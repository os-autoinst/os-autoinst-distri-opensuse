# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot into root filesystem snapshot from boot menu
#  this module tests the read-only snapshot, from console. (1)
#  we print some console output only for nice debugging (1b)
#  if variable UPGRADE is set, we want to check that the 2 snapshots
#  before_upgrade and after upgrade are not identical. test is made
#  by checking the /etc/os-release, this is compatible also for openSUSE-TW (2).
#  The test is also used for testing the snapper rollback functionality.
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use testapi;
use base "opensusebasetest";

sub run {
    my ($self) = @_;
    assert_screen 'linux-login', 200;
    select_console 'root-console';
    # 1)
    assert_script_run('touch /etc/NOWRITE;test ! -f /etc/NOWRITE');
    # 1b) just debugging infos
    assert_script_run("snapper --iso list");
    assert_script_run("cat /etc/os-release");
    if (get_var("UPGRADE")) {
        # if we made a migration, the version should be for example opensuse before migr. 42.1 > 42.2
        # extract number of version id: example SlES 12.2 -> 12.2. for opensuse also ok
        my $OS_VERSION     = script_output("grep VERSION_ID /etc/os-release | cut -c13- | head -c -2");
        my $OLD_OS_VERSION = script_output("grep VERSION_ID /.snapshots/2/snapshot/etc/os-release | cut -c13- | head -c -2");
        # grub_bug bug:956046. menu entry not stable. we could boot in wrong menu-entry.
        if ($OS_VERSION eq $OLD_OS_VERSION) {
            die "OS_VERSION after Rollback matches OS_VERSION before Rollback";
        }
    }
    assert_script_run('snapper rollback');
    assert_script_run('snapper --iso list');
    assert_script_run('snapper --iso list | grep \'number.*first root filesystem.*|\s*$\'',
        fail_message => 'first root filesystem should be marked for cleanup as well');
    assert_script_run('snapper --iso list | grep \'number.*after installation\'.*important=yes');
    assert_script_run('snapper --iso list | grep \'number.*rollback\'.*important=yes',
        fail_message => 'rollback backup should be marked for cleanup fate#321773');
    assert_script_run('snapper --iso list | tail -n 1 | grep \'|\s*|\s*|\s*$\'', fail_message => 'last snapshot should not be cleaned up but is not-important');
    script_run("systemctl reboot", 0);
    reset_consoles;
    $self->wait_boot;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    $self->export_logs;
}

1;

