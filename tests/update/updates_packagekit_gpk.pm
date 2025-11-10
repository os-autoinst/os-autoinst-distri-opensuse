# SUSE's openQA tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: PackageKit gnome-packagekit
# Summary: PackageKit update using gpk
# - Install gnome-packagekit
# - Check if desktop is not locked, unlock if necessary
# - Turn off screensaver and suspend in gnome if DESKTOP is set to "gnome"
# - Otherwise, disable xscreensaver
# - Launch gpk-update-viewer and handle priviledged user warning
# - If a update is available, install it
# - If update matches "PolicyKit" tag, fill password
# - If asked to reboot after update, reboot system
# - If updates requires logout or application restart, close gpk
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "x11test";
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils qw(is_sle is_leap);
use x11utils qw(ensure_unlocked_desktop turn_off_gnome_screensaver turn_off_gnome_suspend default_gui_terminal);
use serial_terminal 'select_serial_terminal';

sub setup_system {
    x11_start_program(default_gui_terminal());

    if (check_var("DESKTOP", "gnome")) {
        turn_off_gnome_screensaver;
        turn_off_gnome_suspend;
    }
    else {
        script_run("xscreensaver-command -exit");
        if (check_var("DESKTOP", "lxde")) {
            # Disable xscreensaver autostart on LXDE (from system wide config and user config)
            script_sudo('sed -i "s/\@xscreensaver -no-splash//" /etc/xdg/lxsession/LXDE/autostart');
            script_run('sed -i "s/\@xscreensaver -no-splash//" ~/.config/lxsession/LXDE/autostart');
        }
    }
    send_key("ctrl-d");
}

sub close_pop_up_windows {
    if (check_screen([qw(Could_not_get_updates Could_not_get_update_details need_restart_application)], timeout => 5)) {
        record_soft_failure 'poo#130468';
        send_key 'alt-c';
        wait_still_screen 3;
        save_screenshot;
    }
}

sub tell_packagekit_to_quit {
    # tell the PackageKit daemon to stop in order to next load with new libzypp
    # this is different from quit_packagekit
    x11_start_program(default_gui_terminal());
    script_run("pkcon quit");
    send_key("ctrl-d");
}

sub handle_failed_update {
    my $counter = @_;
    # click to expand more details
    click_lastmatch;
    save_screenshot;
    if (check_screen('updates_failed_temp_unaccessible')) {
        die 'updates_failed 10 times with 30 sec sleep time between iterations' if $counter == 11;
        sleep 30;
        assert_and_click('pkit_close');
    }
    else {
        die "Failed to process request";
    }
}

# Update with GNOME PackageKit Update Viewer
sub run {
    my ($self) = @_;
    if (is_sle '15+') {
        select_console 'root-console';
        if (script_run 'rpm -q "gnome-packagekit"') {
            zypper_call("in gnome-packagekit", timeout => 90);
        }
    }
    wait_still_screen 3;
    select_console 'x11', await_console => 0;
    ensure_unlocked_desktop;

    my @updates_tags = qw(updates_none updates_available package-updater-privileged-user-warning updates_restart_application updates_installed-restart updates_failed);
    my @updates_installed_tags = qw(updates_none updates_installed-logout updates_installed-restart updates_restart_application updates_failed);

    setup_system;

    my $counter = 0;
    while (1) {
        x11_start_program('gpk-update-viewer', target_match => \@updates_tags, match_timeout => 100);
        $counter += 1;
        if ($testapi::username eq 'root' and match_has_tag("package-updater-privileged-user-warning")) {
            # Special case if gpk-update-viewer is running as root. Click on Continue Anyway and reassert
            send_key "alt-a";    # Continue Anyway
            assert_screen \@updates_tags, 100;
        }

        if (match_has_tag("updates_none")) {
            wait_still_screen 10 if is_leap('=15.6') || is_sle('=15-sp6');
            send_key 'ret';
            close_pop_up_windows;
            return;
        }
        elsif (match_has_tag('updates_failed')) {
            handle_failed_update($counter);
            next;
        }
        elsif (match_has_tag("updates_available")) {
            if (check_screen('updates_not_installed') && $counter >= 2) {
                send_key 'alt-f4';
                select_serial_terminal;
                quit_packagekit;
                zypper_call('up');
                systemctl 'unmask packagekit.service';
                select_console 'x11', await_console => 0;
                last;
            }
            send_key "alt-i";    # install

            # Wait until installation is done
            push @updates_installed_tags, 'Policykit' if is_sle;
            do {
                assert_screen \@updates_installed_tags, 3600;
                if (match_has_tag("Policykit")) {
                    enter_cmd "$password";
                    pop @updates_installed_tags;
                }
                if (match_has_tag("updates_failed")) {
                    handle_failed_update($counter);
                    assert_screen('updates_available');
                    send_key "alt-i";    # install
                    next;
                }
            } while (match_has_tag 'Policykit');
            if (match_has_tag("updates_none")) {
                wait_still_screen 10 if is_leap('=15.6') || is_sle('=15-sp6');
                wait_screen_change { send_key 'ret'; };
                if (check_screen "updates_installed-restart", 0) {
                    power_action 'reboot', textmode => 1;
                    $self->wait_boot;
                    setup_system;
                }
                next;
            }
            elsif (match_has_tag("updates_installed-logout") || match_has_tag("updates_restart_application")) {
                wait_screen_change { send_key "alt-c"; };    # close
                close_pop_up_windows;

                # The logout is not acted upon, which may miss a libzypp update
                # Force reloading of packagekitd (bsc#1075260, poo#30085)
                tell_packagekit_to_quit;
            }
            elsif (match_has_tag("updates_installed-restart")) {
                power_action 'reboot', textmode => 1;
                $self->wait_boot;
                setup_system;
            }
        }
        die "Took too many tries" if $counter >= 20;
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->upload_packagekit_logs;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
