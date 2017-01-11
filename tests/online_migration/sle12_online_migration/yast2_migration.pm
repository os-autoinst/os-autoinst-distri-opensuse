# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sle12 online migration testsuite
# Maintainer: mitiao <mitiao@gmail.com>

use base "y2logsstep";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    if (!is_desktop_installed()) {
        select_console 'root-console';
    }
    else {
        select_console 'x11';
        ensure_unlocked_desktop;
        mouse_hide(1);
        assert_screen 'generic-desktop';

        x11_start_program("xterm");
        # set blank screen to be never for current session
        script_run("gsettings set org.gnome.desktop.session idle-delay 0");
        become_root;
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
    assert_screen 'yast2-migration-target', 300;
    send_key "alt-p";    # focus on the item of possible migration targets
    send_key_until_needlematch 'migration-target-' . get_var("VERSION"), 'down', 5;
    send_key "alt-n";
    # currently scc proxy update channel doesn't have content
    if (!get_var("SCC_PROXY_URL")) {
        assert_screen 'yast2-migration-installupdate', 200;
        send_key "alt-y";
    }
    # workaround for bsc#1013208
    assert_screen ['yast2-migration-proposal', 'yast2-migration-nvidia_sp3_cannot_load'], 200;
    if (match_has_tag 'yast2-migration-nvidia_sp3_cannot_load') {
        send_key "alt-s";
        record_soft_failure 'bsc#1013208: [online migration] nvidia repo is not ready for SLE12 SP3, skip it';
        set_var('SOFTFAIL', 'bsc#1013208');
        assert_screen 'yast2-migration-proposal';
    }
    # giva a little time to check package conflicts
    if (check_screen("yast2-migration-conflicts", 15)) {
        if (!is_desktop_installed()) {
            send_key "alt-c";
            send_key "alt-p";    # show package dependencies
        }
        else {
            assert_and_click 'migration-proposal-packages';
        }
        wait_still_screen(5);    # package dependencies need a few second to open in x11
        save_screenshot;
        die "package conflicts";
    }

    send_key "alt-n";
    assert_screen 'yast2-migration-startupgrade';
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
            send_key "alt-a", 1;
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
        # sometimes reboot takes longer time after online migration
        # give more time to reboot
        $self->wait_boot(bootloader_time => 300, textmode => !is_desktop_installed);
    }
    else {
        wait_serial("yast2-migration-done-0", $timeout) || die "yast2 migration failed";
        type_string "exit\n" if (is_desktop_installed());
    }
}

sub test_flags() {
    return {fatal => 1};
}

sub post_fail_hook() {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;
    select_console 'log-console';
    wait_still_screen(2);
    $self->save_upload_y2logs;
}

1;
# vim: set sw=4 et:
