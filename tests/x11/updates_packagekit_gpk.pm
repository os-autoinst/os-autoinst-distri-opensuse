# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

sub pre_run_hook() {
    # Turn off screensaver
    x11_start_program("xterm");
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
    my @updates_tags           = qw/updates_none updates_available/;
    my @updates_installed_tags = qw/updates_none updates_installed-logout updates_installed-restart/;

    # First update package manager, then packages
    for (1 .. 2) {
        x11_start_program("gpk-update-viewer");

        assert_screen \@updates_tags, 100;
        if (match_has_tag("updates_none")) {
            send_key "ret";
            last;
        }
        elsif (match_has_tag("updates_available")) {
            send_key "alt-i";    # install

            # Authenticate on SLES
            if (check_screen("updates_authenticate")) {
                type_string "$password\n";
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
                send_key "alt-c";    # close

                # Workaround - packagekit stays open leap 42.1, fixed after update
                if (check_screen("updates_available", 5)) {
                    send_key("alt-f4");
                }
            }
        }
    }
}

sub test_flags() {
    return {milestone => 1};
}

1;
