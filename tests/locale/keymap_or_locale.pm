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
use Utils::Backends 'has_ttys';

sub verify_default_keymap_textmode {
    my ($test_string, $tag, %tty) = @_;

    if (defined($tty{console})) {
        select_console($tty{console});
    }
    else {
        send_key('alt-f3');
        # some remote backends can not provide a "not logged in console" so we
        # use a cleared remote terminal instead
        assert_screen(has_ttys() ? 'linux-login' : 'cleared-console');
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
    # uncomment in case of different keyboard than us is used during installation ( feature not ready yet )
    # my $expected   = get_var('INSTALL_KEYBOARD_LAYOUT','us');
    my $expected       = 'us';
    my %keystroke_list = (
        us => '`1234567890-=~!@#$%^&*()_+',
        fr => '²&é"(-è_çà)=~1234567890°+',
        de => '1234567890ß°!"§$%&/()=?',
        cz => ';+ěščřžýáíé=1234567890%'
    );
    my $keystrokes = $keystroke_list{$expected};

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen([qw(linux-login cleared-console)]);
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

