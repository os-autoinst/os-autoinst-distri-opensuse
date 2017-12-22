## no critic (RequireFilenameMatchesPackage);
package x11test;
use base "opensusebasetest";

use strict;
use testapi;
use utils 'type_string_slow';
use version_utils qw(leap_version_at_least sle_version_at_least);

sub post_fail_hook {
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
    send_key 'tab' if sle_version_at_least('15');
    send_key "ret";
    assert_screen "displaymanager";
    # The keyboard focus was losing in gdm of SLE15 bgo#657996
    mouse_set(520, 350) if sle_version_at_least('15');
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

    # Log out and switch back to default session
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    if (sle_version_at_least('15')) {
        assert_and_click 'dm-gnome-shell';
        send_key 'ret';
        assert_screen 'desktop-gnome-shell', 120;
    }
    else {
        assert_and_click 'dm-sle-classic';
        send_key 'ret';
        assert_screen 'desktop-sle-classic', 120;
    }
}

sub test_terminal {
    my ($self, $name) = @_;
    mouse_hide(1);
    x11_start_program($name);
    $self->enter_test_text($name, cmd => 1);
    assert_screen "test-$name-1";
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
