# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Keyboard layout test in console and display manager after boot
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub verify_default_keymap_textmode_non_us {
    my ($test_string, $tag) = @_;
    # Installation with different keyboard layout is not feature ready but
    # in case of autoyast scenarios we can simply test on login prompt without changing tty
    type_string $test_string;
    assert_screen ["${tag}", "${tag}_not_ready"];
    if (match_has_tag "${tag}_not_ready") {
        # i.e: in cz keyboard the first half in the keystroke list is not displayed in 1st login'
        send_key 'ret' for (1 .. 2);
        record_soft_failure 'bsc#1125886 - Special characters when switching keyboard layout only available after 2nd login';
        assert_screen([qw(linux-login cleared-console)]);
        type_string $test_string;
        assert_screen "${tag}";
    }
}
sub verify_default_keymap_textmode {
    my ($test_string, $tag, %tty) = @_;
    if (defined($tty{console})) {
        select_console($tty{console});
    }
    else {
        send_key('alt-f3');
        # Make sure the VT switch happened before matching VT content.
        wait_still_screen;
        # Some remote backends cannot provide a "not logged in console", so we
        # also match cleared console. After snapshot rollback we may end up with
        # cleared console as well.
        assert_screen([qw(linux-login cleared-console)]);
    }
    type_string($test_string);
    assert_screen($tag);
    # clear line in order to add user bernhard to tty group
    # clear line to avoid possible failures in following console tests if scheduled
    send_key("ctrl-w");
}

sub list_locale_settings {
    my ($self, $console) = @_;
    # locale variables might differ from user to user
    select_console($console);
    $self->save_and_upload_log('localectl status', '/tmp/localectl.status.out');
    $self->save_and_upload_log('locale',           '/tmp/locale.out');
}

sub list_locale_etc_settings {
    my $self = shift;
    select_console('user-console');
    $self->save_and_upload_log('cat /etc/X11/xorg.conf.d/00-keyboard.conf', '/tmp/xorg.00-keyboard.conf.out');
    $self->save_and_upload_log('cat /etc/vconsole.conf',                    '/tmp/vconsole.conf.out');
}

sub notification_handler {
    my ($feature, $state) = @_;
    select_console('user-console');
    assert_script_run("(gsettings get $feature && gsettings set $feature $state) 2>/dev/null || true");
}

sub verify_default_keymap_x11 {
    my ($test_string, $tag, $program) = @_;
    notification_handler('org.gnome.DejaDup periodic', 'false') if (check_var('DESKTOP', 'gnome'));
    select_console('x11');
    x11_start_program($program);
    type_string($test_string);
    assert_screen($tag);
    # clear line to avoid possible failures in following tests (eg. updates_packagekit_gpk)
    send_key("ctrl-w");
    # close xterm
    send_key("ctrl-d");
}

sub run {
    my $expected = get_var('INSTALL_KEYBOARD_LAYOUT', 'us');
    # Feature of switching keyboard during installation is not ready yet,
    # so if another language is used it needs to be verfied that the needle represents properly
    # characters on that language.
    my $keystrokes = '`1234567890-=~!@#$%^&*()_+';

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen([qw(linux-login cleared-console)]);
        # We don't run further tests while switching keyboard feature not ready
        return verify_default_keymap_textmode_non_us($keystrokes, "${expected}_keymap") if ($expected ne 'us');
        verify_default_keymap_textmode($keystrokes, "${expected}_keymap");
        verify_default_keymap_textmode($keystrokes, "${expected}_keymap", console => 'root-console');
        ensure_serialdev_permissions;
        verify_default_keymap_textmode($keystrokes, "${expected}_keymap", console => 'user-console');
    }
    elsif (get_var('DESKTOP') && (!check_var('DESKTOP', 'textmode'))) {
        verify_default_keymap_x11($keystrokes, "${expected}_keymap_logged_x11", 'xterm');
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
