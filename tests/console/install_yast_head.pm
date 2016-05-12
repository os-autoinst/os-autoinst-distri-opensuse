# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

# Used only in the yast branch of the distri.
# See also console/add_yast_head

sub run() {
    my $self = shift;

    select 'root-console';

    # precompile regexes
    my $zypper_dup_continue      = qr/^Continue\? \[y/m;
    my $zypper_dup_conflict      = qr/^Choose from above solutions by number or cancel \[1/m;
    my $zypper_dup_notifications = qr/^View the notifications now\? \[y/m;
    my $zypper_dup_error         = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_dup_finish        = qr/^There are some running programs that might use files/m;
    my $zypper_packagekit        = qr/^Tell PackageKit to quit\?/m;
    my $zypper_packagekit_again  = qr/^Try again\?/m;
    my $zypper_repo_disabled     = qr/^Repository '\S+' has been successfully disabled./m;
    my $zypper_installing        = qr/Installing: \S+/;
    my $zypper_dup_fileconflict  = qr/^File conflicts .*^Continue\? \[y/ms;

    script_run("zypper --gpg-auto-import-keys dup --from YaST:Head | tee /dev/$serialdev", 0);

    my $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error, $zypper_dup_fileconflict], 240);
    while ($out) {
        if ($out =~ $zypper_dup_conflict) {
            send_key '1',   1;
            send_key 'ret', 1;
        }
        elsif (($out =~ $zypper_dup_continue) || ($out =~ $zypper_dup_fileconflict)) {
            save_screenshot;
            # confirm zypper dup continue
            send_key 'y',   1;
            send_key 'ret', 1;
            last;
        }
        elsif ($out =~ $zypper_dup_error) {
            save_screenshot;
            $self->result('fail');
            return;
        }
        $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error, $zypper_dup_fileconflict], 120);
    }
    unless ($out) {
        save_screenshot;
        $self->result('fail');
        return;
    }

    # wait for zypper dup finish, accept failures in meantime
    $out = wait_serial([$zypper_dup_finish, $zypper_installing, $zypper_dup_notifications, $zypper_dup_error, $zypper_dup_fileconflict], 240);
    while ($out) {
        if ($out =~ $zypper_dup_notifications) {
            send_key 'n',   1;    # do not show notifications
            send_key 'ret', 1;
        }
        elsif ($out =~ $zypper_dup_fileconflict) {
            send_key 'y',   1;    # overwrite files
            send_key 'ret', 1;
        }
        elsif ($out =~ $zypper_dup_error) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_dup_finish) {
            last;
        }
        else {
            # probably to avoid hitting black screen on video
            send_key 'shift', 1;
        }
        $out = wait_serial([$zypper_dup_finish, $zypper_installing, $zypper_dup_notifications, $zypper_dup_error, $zypper_dup_fileconflict], 240);
    }

    assert_screen "zypper-dup-finish";
    type_string "exit\n";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
