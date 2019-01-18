# SLE12 online migration tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: mitiao <mitiao@gmail.com>

use base 'y2logsstep';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils 'is_desktop_installed';

sub yast2_migration_gnome_remote {
    return check_var('MIGRATION_METHOD', 'yast') && check_var('DESKTOP', 'gnome') && get_var('REMOTE_CONNECTION');
}

sub run {
    my $self = shift;

    # According to bsc#1106017, use yast2 migration in gnome environment is not possible on s390x
    # due to vnc session over xinetd service could be stopped during migration that cause gnome exit
    # so use yast2 migration under root console
    if (!is_desktop_installed() || yast2_migration_gnome_remote) {
        select_console 'root-console';
    }
    else {
        select_console 'x11', await_console => 0;
        ensure_unlocked_desktop;
        mouse_hide(1);
        assert_screen 'generic-desktop';

        x11_start_program('xterm');
        turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
        become_root;
        if (check_var('HDDVERSION', '12') && get_var('MIGRATION_REMOVE_ADDONS')) {
            # use latest yast2-registration version because is not officially available
            assert_script_run 'wget --quiet ' . data_url('yast2-registration-3.1.129.18-1.noarch.rpm');
            zypper_call '--no-gpg-checks in yast2-registration-3.1.129.18-1.noarch.rpm';
            record_info 'workaround', 'until the package is available for SLE 12 GA';
        }
    }

    # remove add-on and leave it registered to setup inconsistency for migration
    # https://trello.com/c/CyjL1Was/837-0-yast-migration-warn-user-in-case-of-inconsistencies
    if (get_var('MIGRATION_REMOVE_ADDONS')) {
        script_run("yast2 add-on; echo yast2-addon-done-\$? > /dev/$serialdev", 0);
        assert_screen 'addon-products';
        send_key 'tab';
        for my $addon (split(/,/, get_var('MIGRATION_REMOVE_ADDONS'))) {
            send_key_until_needlematch 'addon-list-is-selected',         'tab';     # select add-on list
            send_key_until_needlematch 'addon-list-first-adon-selected', 'home';    # go on first addon in list
            send_key_until_needlematch 'addon-' . $addon . '-selected-to-remove', 'down';
            send_key 'alt-t';
            assert_screen 'addon-remove-warning';
            send_key 'alt-t';
            while (1) {
                assert_screen ['addon-yast2-patterns', 'package-conflict-resolution'];
                last if match_has_tag 'addon-yast2-patterns';
                if (match_has_tag 'package-conflict-resolution') {
                    wait_screen_change { send_key 'alt-2' };                        # 1 can end in unresolvable loop
                    wait_screen_change { send_key 'spc' };
                    wait_screen_change { send_key 'alt-o' };
                }
                # wait for next screen, wait_screen_change is sometimes too fast
                wait_still_screen 3;
            }
            send_key 'alt-a';                                                       # accept
            assert_screen 'addon-products', 90;
        }
        wait_still_screen 2;
        send_key 'alt-o';                                                           # ok
        wait_serial('yast2-addon-done-0') || die 'yast2 add-on failed';
    }

    # add-on service should have same name and the rest will be filled with tab
    my %service = qw(
      ha SUSE_Linux_Enterprise_High_Availability_Extension_
      sdk SUSE_Linux_Enterprise_Software_Development_Kit_
      we SUSE_Linux_Enterprise_Workstation_Extension_
    );
    for my $addon (split(/,/, get_var('MIGRATION_REMOVE_ADDONS'))) {
        zypper_call "rs $service{$addon}\t";                                        # remove service
    }

    script_run("yast2 migration; echo yast2-migration-done-\$? > /dev/$serialdev", 0);

    # yast2 migration would check and install minimal update before migration
    # if the system doesn't perform full update or minimal update
    if (!(get_var("FULL_UPDATE") || get_var("MINIMAL_UPDATE"))) {
        assert_screen 'yast2-migration-onlineupdates';
        send_key "alt-y";
        assert_screen 'yast2-migration-updatesoverview';
        if (!is_desktop_installed()) {
            send_key "alt-a";
        }
        else {
            # the shortcut key alt-a doesn't work in graphic mode
            assert_and_click 'yast2-migration-accept-patch';
        }
    }

    # wait for migration target after needed updates installed
    assert_screen ['yast2-migration-target', 'yast2-migration-inconsistency'], 300;
    if (match_has_tag 'yast2-migration-inconsistency') {
        if (get_var('MIGRATION_INCONSISTENCY_DEACTIVATE')) {
            send_key 'alt-d';    # deactivate
        }
        elsif (get_var('MIGRATION_INCONSISTENCY_INSTALL')) {
            wait_screen_change { send_key 'alt-t' };    # install product
            assert_screen ['yast2-migration-addon-not-installed', 'yast2-migration-inconsistency', 'yast2-migration-target'], 150;
            if (match_has_tag 'yast2-migration-addon-not-installed') {
                send_key 'alt-o';                       # ok
                assert_screen 'yast2-migration-inconsistency';
                send_key 'alt-c';                       # continue
                for my $addon (split(/,/, get_var('MIGRATION_REMOVE_ADDONS'))) {
                    assert_screen 'yast2-migration-add-addon';
                    send_key 'alt-y';                   # yes
                }
            }
            if (match_has_tag 'yast2-migration-inconsistency') {
                wait_screen_change { send_key 'alt-c' };    # continue
            }
        }
    }
    assert_screen 'yast2-migration-target';
    send_key "alt-p";                                       # focus on the item of possible migration targets
    send_key_until_needlematch 'migration-target-' . get_var("VERSION"), 'down', 5;
    send_key "alt-n";
    assert_screen ['yast2-migration-installupdate', 'yast2-migration-proposal'], 500;
    if (match_has_tag 'yast2-migration-installupdate') {
        send_key 'alt-y';
    }
    # giva a little time to check package conflicts
    if (check_screen("yast2-migration-conflicts", 15)) {
        if (!is_desktop_installed()) {
            send_key "alt-c";
            send_key "alt-p";                               # show package dependencies
        }
        else {
            assert_and_click 'migration-proposal-packages';
        }
        wait_still_screen(5);                               # package dependencies need a few second to open in x11
        save_screenshot;
        if (get_var('RESOLVE_PACKAGE_CONFLICTS')) {
            while (1) {
                assert_screen ['package-conflict-resolution', 'addon-yast2-patterns'], 90;
                last if match_has_tag 'addon-yast2-patterns';
                if (match_has_tag 'package-conflict-resolution') {
                    wait_screen_change { send_key 'alt-1' };
                    if (!check_screen 'radio-button-selected', 0) {
                        wait_screen_change { send_key 'spc' };
                    }
                    wait_screen_change { send_key 'alt-o' };
                }
                # wait for next screen, wait_screen_change is sometimes too fast
                wait_still_screen 3;
            }
            wait_screen_change { send_key 'alt-a' };
            while (1) {
                assert_screen ['automatic-changes', '3rdpartylicense'];
                if (match_has_tag '3rdpartylicense') {
                    wait_screen_change { send_key 'alt-a' };
                }
                elsif (match_has_tag 'automatic-changes') {
                    wait_screen_change { send_key 'alt-o' };
                    last;
                }
            }
            assert_screen 'yast2-migration-proposal';
            wait_screen_change { send_key 'alt-n' };
        }
        else {
            die "package conflicts";
        }
    }

    send_key "alt-n";
    assert_screen 'yast2-migration-startupgrade', 90;
    send_key "alt-u";
    assert_screen "yast2-migration-upgrading";

    # start migration
    my $timeout = 7200;
    my @tags    = qw(
      yast2-migration-wrongdigest yast2-migration-packagebroken yast2-migration-internal-error
      yast2-migration-finish      yast2-migration-notifications
    );
    while (1) {
        assert_screen \@tags, $timeout;
        if (match_has_tag("yast2-migration-internal-error")) {
            $self->result('fail');
            send_key "alt-o";
            save_screenshot;
            return;
        }
        elsif (match_has_tag("yast2-migration-packagebroken")) {
            $self->result('fail');
            send_key "alt-d";
            save_screenshot;
            send_key "alt-s";
            return;
        }
        elsif (match_has_tag("yast2-migration-wrongdigest")) {
            $self->result('fail');
            send_key "alt-a";
            save_screenshot;
            send_key "alt-n";
            return;
        }
        elsif (match_has_tag("yast2-migration-notifications")) {
            # close notification window
            send_key "alt-o";
            # wait a second after pressing close button
            wait_still_screen(1);
        }
        last if (match_has_tag("yast2-migration-finish"));
    }
    send_key "alt-f";

    # after migration yast may ask to reboot system
    if (check_screen("yast2-ask-reboot", 5)) {
        # reboot
        send_key "alt-r";
        power_action('reboot', observe => 1, keepconsole => 1);
        # sometimes reboot takes longer time after online migration
        # give more time to reboot
        $self->wait_boot(bootloader_time => 300, textmode => !is_desktop_installed);
    }
    else {
        wait_serial("yast2-migration-done-0", $timeout) || die "yast2 migration failed";
        type_string "exit\n" if (is_desktop_installed());
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->save_and_upload_log('journalctl -b', '/tmp/journal.log', {screenshot => 1});
    $self->upload_xsession_errors_log;
    $self->SUPER::post_fail_hook;
}

1;
