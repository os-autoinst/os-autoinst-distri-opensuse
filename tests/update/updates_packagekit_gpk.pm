# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
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
use version_utils qw(is_sle is_leap);

sub turn_off_screensaver {
    my ($self) = @_;
    # Turn off screensaver
    x11_start_program('xterm');
    become_root;
    ensure_serialdev_permissions;

    # Trying to detect bsc#1052258 which leads to the test failure occasionally on Leap 42.3 which has affected kernel version
    if (is_leap('=42.3') && script_run("dmesg | grep -P 'soft lockup - CPU#\\d+ stuck'")) {
        # Fail on cpu stuck, see bsc#1052258 and collect logs if machine still responds
        record_soft_failure 'cpu soft lockup detected, see bsc#1052258';
        $self->save_upload_y2logs;
        select_console 'x11';    # Trying to continue with the test
    }

    type_string "exit\n";

    if (check_var("DESKTOP", "gnome")) {
        script_run("gsettings set org.gnome.desktop.session idle-delay 0");
    }
    else {
        script_run("xscreensaver-command -exit");
    }
    send_key("ctrl-d");
}

sub tell_packagekit_to_quit {
    # tell the PackageKit daemon to stop in order to next load with new libzypp
    # this is different from pkcon_quit
    x11_start_program('xterm');
    script_run("pkcon quit");
    send_key("ctrl-d");
}

# Update with GNOME PackageKit Update Viewer
sub run {
    my ($self) = @_;
    if (is_sle '15+') {
        select_console 'root-console';
        zypper_call("in gnome-packagekit", timeout => 90);
        record_soft_failure 'bsc#1081584';
    }
    select_console 'x11', await_console => 0;

    my @updates_tags           = qw(updates_none updates_available package-updater-privileged-user-warning updates_restart_application);
    my @updates_installed_tags = qw(updates_none updates_installed-logout updates_installed-restart updates_restart_application );

    $self->turn_off_screensaver;

    while (1) {
        x11_start_program('gpk-update-viewer', target_match => \@updates_tags, match_timeout => 100);

        if ($testapi::username eq 'root' and match_has_tag("package-updater-privileged-user-warning")) {
            # Special case if gpk-update-viewer is running as root. Click on Continue Anyway and reassert
            send_key "alt-a";    # Continue Anyway
            assert_screen \@updates_tags, 100;
        }

        if (match_has_tag("updates_restart_application")) {
            assert_and_click("updates_restart_application");

            # We also need the daemon to reload to pick up libzypp updates
            # Force reloading of packagekitd (bsc#1075260, poo#30085)
            tell_packagekit_to_quit;
        }

        if (match_has_tag("updates_none")) {
            send_key 'ret';
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
                send_key 'ret';
                if (check_screen "updates_installed-restart", 0) {
                    power_action 'reboot', textmode => 1;
                    $self->wait_boot;
                    $self->turn_off_screensaver;
                }
                next;
            }
            elsif (match_has_tag("updates_installed-logout")) {
                send_key "alt-c";    # close

                # The logout is not acted upon, which may miss a libzypp update
                # Force reloading of packagekitd (bsc#1075260, poo#30085)
                tell_packagekit_to_quit;
            }
            elsif (match_has_tag("updates_installed-restart")) {
                power_action 'reboot', textmode => 1;
                $self->wait_boot;
                $self->turn_off_screensaver;
            }
        }
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
