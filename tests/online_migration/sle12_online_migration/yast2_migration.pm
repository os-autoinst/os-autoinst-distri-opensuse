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
use utils;

sub run {
    my $self = shift;

    if (get_var("DESKTOP") =~ /textmode|minimalx/) {
        select_console 'root-console';
    }
    else {
        select_console 'x11';
        wait_still_screen;
        check_screenlock;
        mouse_hide(1);
        assert_screen 'generic-desktop';

        x11_start_program("xterm");
        # set blank screen to be never for current session
        script_run("gsettings set org.gnome.desktop.session idle-delay 0");
        become_root;
    }

    script_run("/sbin/yast2 migration; echo yast2-migration-done-\$? > /dev/$serialdev", 0);

    # install minimal update before migration if not perform full update
    if (!get_var("FULL_UPDATE")) {
        assert_screen 'yast2-migration-onlineupdates';
        send_key "alt-y";
        assert_screen 'yast2-migration-updatesoverview';
        if (get_var("DESKTOP") =~ /textmode|minimalx/) {
            send_key "alt-a";
        }
        else {
            # the shortcut key alt-a doesn't work in graphic mode
            assert_and_click 'yast2-migration-accept-patch';
        }
    }

    # wait for migration target after needed updates installed
    assert_screen 'yast2-migration-target', 300;
    send_key "alt-n";
    # currently scc proxy update channel doesn't have content
    if (!get_var("SCC_PROXY_URL")) {
        assert_screen 'yast2-migration-installupdate', 200;
        send_key "alt-y";
    }
    assert_screen 'yast2-migration-proposal', 60;

    # giva a little time to check package conflicts
    if (check_screen("yast2-migration-conflicts", 15)) {
        send_key_until_needlematch 'migration-proposal-packages', 'tab', 3;
        send_key "ret";
        save_screenshot;
        $self->result('fail');
        return;
    }
    send_key "alt-n";
    assert_screen 'yast2-migration-startupgrade';
    send_key "alt-u";
    assert_screen "yast2-migration-upgrading";

    # start migration
    my $timeout = 3000;
    my @tags    = qw/yast2-migration-wrongdigest yast2-migration-packagebroken yast2-migration-internal-error yast2-migration-finish/;
    while (1) {
        my $ret = assert_screen \@tags, $timeout;
        if ($ret->{needle}->has_tag("yast2-migration-internal-error")) {
            $self->result('fail');
            send_key "alt-o";
            save_screenshot;
            return;
        }
        elsif ($ret->{needle}->has_tag("yast2-migration-packagebroken")) {
            $self->result('fail');
            send_key "alt-d";
            save_screenshot;
            send_key "alt-s";
            return;
        }
        elsif ($ret->{needle}->has_tag("yast2-migration-wrongdigest")) {
            $self->result('fail');
            send_key "alt-a", 1;
            save_screenshot;
            send_key "alt-n";
            return;
        }
        last if $ret->{needle}->has_tag("yast2-migration-finish");
    }
    send_key "alt-f";

    # after migration yast may ask to reboot system
    if (check_screen("yast2-ask-reboot", 5)) {
        send_key "alt-c";    # cancel it and reboot in post migration step
    }

    wait_serial("yast2-migration-done-0", $timeout) || die "yast2 migration failed";
    type_string "exit\n" if (get_var("DESKTOP") !~ /textmode|minimalx/);
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
