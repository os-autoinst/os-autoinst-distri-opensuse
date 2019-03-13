# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Check that health-check service works correctly
# Maintainer: Ciprian Cret <ccret@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use transactional qw(process_reboot trup_install trup_shell);
use version_utils 'is_caasp';
use utils;


sub get_btrfsid {
    my $btrfs_id = script_output("btrfs subvolume get-default /");
    $btrfs_id =~ /ID (\d+) gen/;
    $btrfs_id = $1;
    return $btrfs_id;
}

sub get_loggedid {
    my $logged_id = script_output("cat /var/lib/misc/health-check.state");
    $logged_id =~ /LAST_WORKING_BTRFS_ID=(\d+)/;
    $logged_id = $1;
    return $logged_id;
}

sub compare_id {
    my $btrfs_id = get_btrfsid;
    my $hc_id    = get_loggedid;
    die "The current snapshot id does not match the one from the health-checker log" unless $hc_id == $btrfs_id;
}

sub run {
    if (script_run 'rpm -q health-checker') {
        record_soft_failure 'bsc#1134176';
        trup_install 'health-checker';
        systemctl 'enable health-checker';
    }

    # run health-checker to make sure the current snapshot doesn't have issues
    validate_script_output("health-checker", sub { m/passed/ });

    # keep the current snapshot id and compare it to the logged one
    my $initial_id = get_btrfsid;
    compare_id;

    # update rebootmgr.sh to force health-checker to fail
    assert_script_run "cp /usr/lib/health-checker/rebootmgr.sh /tmp/rebootmgr_bk.sh";
    trup_shell "sed -i 's/exit 0/exit 1/g' /usr/lib/health-checker/rebootmgr.sh", reboot => 0;

    # check that the changes applied and we have a new snapshot
    my $current_id = get_btrfsid;
    my $logged_id  = get_loggedid;
    die "The current snapshot is not ahead of the logged one" unless $current_id > $logged_id;

    # Automated rollback shows grub menu twice (timeout disabled)
    type_string "reboot\n";
    assert_screen 'grub2', 100;
    wait_screen_change { send_key 'ret' };
    process_reboot;

    my $final_id = get_btrfsid;
    die "health-checker does not rollback to the correct snapshot" unless $initial_id == $final_id;

    compare_id;

    # run health-checker again. If the rollback was correct the check should pass
    validate_script_output("health-checker", sub { m/passed/ });
}

sub post_fail_hook {
    script_run "journalctl -u health-checker > health-checker.log", 60;
    upload_logs "health-checker.log";

    # revert changes to rebootmgr.sh and reboot
    if (script_run "test -e /tmp/rebootmgr_bk") {
        trup_shell "mv /tmp/rebootmgr_bk.sh /usr/lib/health-checker/rebootmgr.sh";
    }
}

1;
