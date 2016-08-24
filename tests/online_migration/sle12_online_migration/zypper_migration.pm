# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;
    select_console 'root-console';

    # precompile regexes
    my $zypper_continue               = qr/^Continue\? \[y/m;
    my $zypper_migration_target       = qr/\[num\/q\]/m;
    my $zypper_disable_repos          = qr/^Disable obsolete repository/m;
    my $zypper_migration_conflict     = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_migration_error        = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_migration_fileconflict = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_migration_done         = qr/^Executing.*after online migration|^ZYPPER-DONE/m;
    my $zypper_migration_notification = qr/^View the notifications now\? \[y/m;
    my $zypper_migration_failed       = qr/^Migration failed/m;

    # start migration
    script_run("(zypper migration;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);
    # migration process take long time
    my $timeout          = 7200;
    my $migration_checks = [$zypper_migration_target, $zypper_disable_repos, $zypper_continue, $zypper_migration_done, $zypper_migration_error, $zypper_migration_conflict, $zypper_migration_fileconflict, $zypper_migration_notification, $zypper_migration_failed];
    my $out              = wait_serial($migration_checks, $timeout);
    while ($out) {
        if ($out =~ $zypper_migration_target) {
            my $version = get_var("VERSION");
            $version =~ s/-/ /;
            if ($out =~ /(\d+)\s+\|\s+SUSE Linux Enterprise.*?$version/m) {
                send_key "$1";
            }
            send_key "ret";
            save_screenshot;
        }
        elsif ($out =~ $zypper_disable_repos) {
            send_key "y";
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_error || $out =~ $zypper_migration_conflict || $out =~ $zypper_migration_fileconflict || $out =~ $zypper_migration_failed) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_continue) {
            send_key "y";
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_notification) {
            send_key "n";    #do not view package update notification by default
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_done) {
            last;
        }
        $out = wait_serial($migration_checks, $timeout);
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
