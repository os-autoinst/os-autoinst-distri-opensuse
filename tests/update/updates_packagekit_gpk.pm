# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: PackageKit update using gpk
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "x11test";
use strict;
use testapi;
use utils;

sub turn_off_screensaver() {
    # Turn off screensaver
    x11_start_program("xterm");
    assert_screen('xterm');

    # in case we rebooted
    assert_script_sudo "chown $testapi::username /dev/$testapi::serialdev";

    if (check_var("DESKTOP", "gnome")) {
        script_run("gsettings set org.gnome.desktop.session idle-delay 0");
    }
    else {
        script_run("xscreensaver-command -exit");
    }
    send_key("ctrl-d");
}

# Update with GNOME PackageKit Update Viewer
sub run() {
    my ($self) = @_;
    select_console 'x11';

    my @updates_tags           = qw(updates_none updates_available);
    my @updates_installed_tags = qw(updates_none updates_installed-logout updates_installed-restart);

    turn_off_screensaver;

    while (1) {
        x11_start_program("gpk-update-viewer");

        assert_screen \@updates_tags, 100;
        if (match_has_tag("updates_none")) {
            send_key "ret";
            return;
        }
        elsif (match_has_tag("updates_available")) {
            send_key "alt-i";    # install

            # Authenticate on SLES
            # FIXME: actually only do that on SLE
            push @updates_installed_tags, 'updates_authenticate';
            check_screen \@updates_installed_tags;
            if (match_has_tag("updates_authenticate")) {
                type_string "$password\n";
                pop @updates_installed_tags;
            }

            # Wait until installation is done
            assert_screen \@updates_installed_tags, 3600;
            if (match_has_tag("updates_none")) {
                send_key "ret";
                last;
            }
            elsif (match_has_tag("updates_installed-logout")) {
                send_key "alt-c";    # close
            }
            elsif (match_has_tag("updates_installed-restart")) {
                select_console 'root-console';
                type_string "reboot\n";
                $self->wait_boot;
                turn_off_screensaver;
            }
        }
    }
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
