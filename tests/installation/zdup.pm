# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Offline migration using the DVD medium as repository with
#   `zypper dup`
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use testapi;
use strict;
use warnings;
use testapi;
use utils qw(OPENQA_FTP_URL zypper_call);

sub run {
    my $self = shift;

    # precompile regexes
    my $zypper_dup_continue      = qr/^Continue\? \[y/m;
    my $zypper_dup_conflict      = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_dup_notifications = qr/^View the notifications now\? \[y/m;
    my $zypper_dup_error         = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_dup_finish        = qr/^There are some running programs that might use files|ZYPPER-DONE/m;
    my $zypper_dup_fileconflict  = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_retrieving        = qr/Retrieving: \S+/;
    my $zypper_check_conflicts   = qr/Checking for file conflicts: \S+/;

    my $dup_args = get_var('ZDUP_FORCE_RESOLUTION') ? '--force-resolution' : '';

    script_run("(zypper dup $dup_args -l;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);

    my $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 240);
    while ($out) {
        if ($out =~ $zypper_dup_conflict) {
            if (get_var("WORKAROUND_DEPS")) {
                record_info 'workaround dependencies';
                send_key '1';
                send_key 'ret';
            }
            else {
                $self->result('fail');
                save_screenshot;
                return;
            }
        }
        elsif ($out =~ $zypper_dup_continue) {
            # confirm zypper dup continue
            send_key 'y';
            send_key 'ret';
            last;
        }
        elsif ($out =~ $zypper_dup_error) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        save_screenshot;
        $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 120);
    }
    unless ($out) {
        $self->result('fail');
        save_screenshot;
        return;
    }

    # wait for zypper dup finish, accept failures in meantime
    my $post_checks = [$zypper_dup_finish, $zypper_dup_notifications, $zypper_dup_error, $zypper_dup_fileconflict, $zypper_check_conflicts, $zypper_retrieving];
    $out = wait_serial($post_checks, 3600);
    while ($out) {
        if ($out =~ $zypper_dup_notifications) {
            send_key 'n';    # do not show notifications
            send_key 'ret';
        }
        elsif ($out =~ $zypper_dup_error) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_dup_finish) {
            last;
        }
        elsif ($out =~ $zypper_retrieving or $out =~ $zypper_check_conflicts) {
            # probably to avoid hitting black screen on video
            send_key 'shift';
            # continue but do a check again
            $out = wait_serial($post_checks, 3600);
            next;
        }
        elsif ($out =~ $zypper_dup_fileconflict) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        else {
            # probably to avoid hitting black screen on video
            send_key 'shift';
        }
        save_screenshot;
        $out = wait_serial([$zypper_dup_finish, $zypper_dup_notifications, $zypper_dup_error], 3600);
    }

    assert_screen "zypper-dup-finish";
    if (script_run '! test -e /etc/issue') {
        record_soft_failure 'bsc#1133636';
        zypper_call 'in issue-generator';
    }
}

1;
