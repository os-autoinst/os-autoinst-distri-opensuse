# SLE12 online migration tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SLE 12 online migration using zypper migration
# Maintainer: mitiao <mitiao@gmail.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';

sub run {
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
    my $zypper_migration_license      = qr/Do you agree with the terms of the license\? \[y/m;
    my $zypper_migration_urlerror     = qr/URI::InvalidURIError/m;
    my $zypper_migration_reterror     = qr/^No migration available|Can't get available migrations/m;

    # start migration
    script_run("(zypper migration;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);
    # migration process take long time
    my $timeout          = 7200;
    my $migration_checks = [
        $zypper_migration_target, $zypper_disable_repos,      $zypper_continue,               $zypper_migration_done,
        $zypper_migration_error,  $zypper_migration_conflict, $zypper_migration_fileconflict, $zypper_migration_notification,
        $zypper_migration_failed, $zypper_migration_license,  $zypper_migration_reterror
    ];
    my $zypper_migration_error_cnt = 0;
    my $out                        = wait_serial($migration_checks, $timeout);
    while ($out) {
        if ($out =~ $zypper_migration_target) {
            my $version = get_var("VERSION");
            $version =~ s/-/ /;
            if ($out =~ /(\d+)\s+\|\s+SUSE Linux Enterprise.*?$version/m) {
                send_key "$1";
            }
            else {
                die 'No expected migration target found';
            }
            send_key "ret";
            save_screenshot;
        }
        elsif ($out =~ $zypper_disable_repos) {
            send_key "y";
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_error) {
            $zypper_migration_error_cnt += 1;
            die 'Migration failed with zypper error' if $zypper_migration_error_cnt > 3;
            record_info("Migration error [$zypper_migration_error_cnt/3]",
                'zypper migration error, will sleep for a while and retry',
                result => 'softfail');
            sleep 60;
            # Retry zypper action
            send_key 'r';
            send_key 'ret';
        }
        elsif ($out =~ $zypper_migration_conflict
            || $out =~ $zypper_migration_fileconflict
            || $out =~ $zypper_migration_failed
            || $out =~ $zypper_migration_urlerror)
        {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_continue) {
            send_key "y";
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_license) {
            type_string "yes";
            save_screenshot;
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_notification) {
            send_key "n";    #do not view package update notification by default
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_done) {
            die 'Migration failed with zypper error' if ($out =~ $zypper_migration_reterror);
            last;
        }
        $out = wait_serial($migration_checks, $timeout);
    }
    power_action('reboot', keepconsole => 1, textmode => 1);

    # sometimes reboot takes longer time after online migration, give more time
    $self->wait_boot(bootloader_time => 300);
}

1;
