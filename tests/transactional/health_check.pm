# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: health-checker
# Summary: Check that health-check service works correctly
# Maintainer: Ciprian Cret <ccret@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use transactional qw(process_reboot trup_install trup_shell);
use Utils::Architectures qw(is_s390x);
use version_utils qw(is_sle_micro);


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
    my $hc_id = get_loggedid;
    die "The current snapshot id does not match the one from the health-checker log" unless $hc_id == $btrfs_id;
}

sub run {
    select_console 'root-console';

    if (script_run 'rpm -q health-checker') {
        trup_install 'health-checker';
        systemctl 'enable health-checker';
    }

    # run health-checker to make sure the current snapshot doesn't have issues
    validate_script_output("health-checker", sub { m/passed/ });

    # keep the current snapshot id and compare it to the logged one
    my $initial_id = get_btrfsid;
    compare_id;

    # update rebootmgr.sh to force health-checker to fail
    trup_shell 'f=$(rpm --eval %{_libexecdir})/health-checker/fail.sh; echo -e \'#/bin/sh\n[ "$1" != "check" ]\' > $f && chmod a+x $f', reboot => 0;

    # check that the changes applied and we have a new snapshot
    my $current_id = get_btrfsid;
    my $logged_id = get_loggedid;
    die "The current snapshot is not ahead of the logged one" unless $current_id > $logged_id;

    # Automated rollback shows grub menu twice (timeout disabled)
    process_reboot(automated_rollback => 1);

    my $final_id = get_btrfsid;
    unless ($initial_id == $final_id) {
        if (is_sle_micro && is_s390x) {
            record_soft_failure "bsc#1191897 - [s390x] health-checker does not rollback to the correct snapshot";
        } else {
            die "health-checker does not rollback to the correct snapshot";
        }
    }


    compare_id;

    # run health-checker again. If the rollback was correct the check should pass
    validate_script_output("health-checker", sub { m/passed/ });
}

sub post_fail_hook {
    script_run "journalctl -u health-checker -o short-precise > health-checker.log", 60;
    upload_logs "health-checker.log";

    # revert changes to rebootmgr.sh and reboot
    if (script_run('test -e $(rpm --eval %{_libexecdir})/health-checker/fail.sh') == 0) {
        trup_shell 'rm $(rpm --eval %{_libexecdir})/health-checker/fail.sh';
    }
}

1;
