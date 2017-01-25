## no critic (RequireFilenameMatchesPackage);
package x11test;
use base "opensusebasetest";

# Base class for all openSUSE tests

use strict;
use testapi;

sub post_fail_hook() {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    $self->export_kde_logs;
    $self->export_logs;

    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

# logout and switch window-manager
sub switch_wm {
    mouse_set(1000, 30);
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout-system";
    assert_screen "logout-dialogue";
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "originUser-login-dm";
    type_password;
}

# shared between gnome_class_switch and gdm_session_switch
sub prepare_sle_classic {
    my ($self) = @_;

    # Log out and switch to GNOME Classic
    assert_screen "generic-desktop";
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome-classic";
    send_key "ret";
    assert_screen "desktop-gnome-classic", 120;
    $self->application_test;

    # Log out and switch to SLE Classic
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-sle-classic";
    send_key "ret";
    assert_screen "desktop-sle-classic", 120;
}

sub enter_test_text {
    my ($self, $name) = @_;
    $name //= 'your program';
    for (1 .. 13) { send_key "ret" }
    type_string "echo If you can see this text $name is working.\n";
}

sub test_terminal {
    my ($self, $name) = @_;
    mouse_hide(1);
    x11_start_program($name);
    $self->enter_test_text($name);
    assert_screen "test-$name-1";
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
