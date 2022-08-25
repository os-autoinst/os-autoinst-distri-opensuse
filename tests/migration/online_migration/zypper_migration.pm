# SLE online migration tests
#
# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper, transactional-update
# Summary: SLE online migration using zypper migration or transactional update
# Maintainer: yutao <yuwang@suse.com>, <qa-c@suse.de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils qw(is_desktop_installed is_sles4sap is_leap_migration is_sle_micro);
use Utils::Backends 'is_pvm';
use transactional;

sub check_migrated_version {
    # check if the migration success or not by checking the /etc/os-release file with the VERSION
    my $target_version = get_var("TARGET_VERSION", get_required_var("VERSION"));
    assert_script_run("grep VERSION= /etc/os-release | grep $target_version");
}

sub run {
    my $self = shift;
    select_console 'root-console';

    # precompile regexes
    my $zypper_continue = qr/^Continue\? \[y/m;
    my $zypper_migration_target = qr/\[num\/q\]/m;
    my $zypper_disable_repos = qr/^Disable obsolete repository/m;
    my $zypper_migration_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_migration_error = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_migration_fileconflict = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_migration_done = qr/^Executing.*after online migration|^ZYPPER-DONE/m;
    my $zypper_migration_notification = qr/^View the notifications now\? \[y/m;
    my $zypper_migration_failed = qr/^Migration failed/m;
    my $zypper_migration_bsc1184347 = qr/rpmdb2solv: invalid option -- 'D'/m;
    my $zypper_migration_bsc1196114 = qr/scriptlet failed, exit status 127/m;
    my $zypper_migration_license = qr/Do you agree with the terms of the license\? \[y/m;
    my $zypper_migration_urlerror = qr/URI::InvalidURIError/m;
    my $zypper_migration_reterror = qr/^No migration available|Can't get available migrations/m;

    my $zypper_migration_signing_key = qr/^Do you want to reject the key, trust temporarily, or trust always?[\s\S,]* \[r/m;
    # start migration
    if (is_sle_micro) {
        # We need to stop and disable apparmor service before migration due to bsc#1197368
        systemctl('disable --now apparmor.service');
        script_run("(transactional-update migration; echo ZYPPER-DONE) | tee /dev/$serialdev", 0);
    } else {
        my $option = (is_leap_migration) || (get_var("SCC_ADDONS") =~ /phub/) || (get_var("SMT_URL") =~ /smt/) ? " --allow-vendor-change " : " ";
        script_run("(zypper migration $option; echo ZYPPER-DONE) |& tee /dev/$serialdev", 0);
    }
    # migration process take long time, and for leap to sle, we need 4 hours for
    # kde zypper migration.
    my $timeout = (is_leap_migration) ? 18000 : 7200;
    my $migration_checks = [
        $zypper_migration_bsc1184347, $zypper_migration_bsc1196114,
        $zypper_migration_target, $zypper_disable_repos, $zypper_continue, $zypper_migration_done,
        $zypper_migration_error, $zypper_migration_conflict, $zypper_migration_fileconflict, $zypper_migration_notification,
        $zypper_migration_failed, $zypper_migration_license, $zypper_migration_reterror, $zypper_migration_signing_key
    ];
    my $zypper_migration_error_cnt = 0;
    my $out = wait_serial($migration_checks, $timeout);
    while ($out) {
        diag "out=$out";
        if ($out =~ $zypper_migration_target) {
            my $target_version = get_var("TARGET_VERSION", get_required_var("VERSION"));
            $target_version =~ s/-/ /;
            if ($out =~ /(\d+)\s+\|\s?SUSE Linux Enterprise.*?$target_version/m) {
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
        elsif ($out =~ $zypper_migration_bsc1196114) {
            # another case of migration LTSS to LTSS, when dependensies are in LTSS which is not part of migration
            record_soft_failure('bsc#1196114');
            send_key 'i';
            send_key 'ret';
        }
        elsif ($out =~ $zypper_migration_bsc1184347) {
            # migration is done, but zypper failed because of the bug
            # LTSS can't be migrated, and there is fix for the bug
            # othwerwise migration is done, test can continue, libsolv will be updated later
            record_soft_failure('bsc#1184347');
            last;
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
        elsif ($out =~ $zypper_migration_conflict)
        {
            if (check_var("BREAK_DEPS", '1')) {
                # This is a workaround for leap to sle migration, we need choose 2 to resolve conflicts.
                # Normally we do not need resolve any conflicts during migration.
                is_leap_migration ? send_key '2' : send_key '1';
                send_key 'ret';
            } else {
                save_screenshot;
                die 'Zypper migration failed';
            }
        }
        elsif ($out =~ $zypper_migration_signing_key)
        {
            send_key 'a';
            send_key 'ret';
        }
        elsif ($out =~ $zypper_migration_fileconflict
            || $out =~ $zypper_migration_failed
            || $out =~ $zypper_migration_urlerror)
        {
            save_screenshot;
            die 'Zypper migration failed';
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

    select_console('root-console', await_console => 0);
    # wait long time for snapper to settle down
    assert_screen 'root-console', 600;

    # We can't use 'keepconsole' here, because sometimes a display-manager upgrade can lead to a screen change
    # during restart of the X/GDM stack
    if (is_sle_micro) {
        check_reboot_changes;
        check_migrated_version;
    } else {
        power_action('reboot', textmode => 1);
        reconnect_mgmt_console if is_pvm;
        # Do not attempt to log into the desktop of a system installed with SLES4SAP
        # being prepared for upgrade, as it does not have an unprivileged user to test
        # with other than the SAP Administrator
        #
        # sometimes reboot takes longer time after online migration, give more time
        $self->wait_boot(textmode => !is_desktop_installed, bootloader_time => 500, ready_time => 600, nologin => is_sles4sap);
    }
}

sub post_fail_hook {
    my $self = shift;
    $self->select_serial_terminal;
    script_run("pkill zypper");
    upload_logs '/var/log/zypper.log';
    $self->upload_solvertestcase_logs();
    $self->SUPER::post_fail_hook;
}

1;
