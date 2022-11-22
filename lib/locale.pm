# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

package locale;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends 'has_ttys';
use x11utils 'turn_off_gnome_suspend';

sub verify_default_keymap_textmode_non_us {
    my ($self, $test_string, $tag) = @_;
    # Installation with different keyboard layout is not feature ready but
    # in case of autoyast scenarios we can simply test on login prompt without changing tty
    type_string $test_string;
    assert_screen ["${tag}", "${tag}_not_ready"];
    if (match_has_tag "${tag}_not_ready") {
        # i.e: in cz keyboard the first half in the keystroke list is not displayed in 1st login'
        send_key 'ret' for (1 .. 2);
        assert_screen 'login-incorrect';
        record_soft_failure 'bsc#1125886 - Special characters when switching keyboard layout only available after 2nd login';
        assert_screen([qw(linux-login cleared-console)]);
        type_string $test_string;
        assert_screen "${tag}";
    }
}

sub verify_default_keymap_textmode {
    my ($self, $test_string, $tag, %tty) = @_;

    if (defined($tty{console})) {
        select_console($tty{console});
    }
    else {
        send_key('alt-f3');
        # remote backends can not provide a "not logged in console" so we use
        # a cleared remote terminal instead
        assert_screen(has_ttys() ? 'linux-login' : 'cleared-console');
    }

    wait_still_screen;
    type_string($test_string);
    assert_screen($tag);
    # clear line in order to add user bernhard to tty group
    # clear line to avoid possible failures in following console tests if scheduled
    assert_screen_change { send_key("ctrl-u") };
}

sub notification_handler {
    my ($feature, $state) = @_;

    select_console('user-console');
    assert_script_run("(gsettings get $feature && gsettings set $feature $state) 2>/dev/null || true");
}

sub verify_default_keymap_x11 {
    my ($self, $test_string, $tag, $program) = @_;
    notification_handler('org.gnome.DejaDup periodic', 'false') if (check_var('DESKTOP', 'gnome'));
    turn_off_gnome_suspend if (check_var('DESKTOP', 'gnome'));
    select_console('x11');
    x11_start_program($program);
    type_string($test_string);
    assert_screen($tag);
    # clear line to avoid possible failures in following tests (eg. updates_packagekit_gpk)
    send_key("ctrl-w");
    # close xterm
    send_key("ctrl-d");
}

sub get_keystroke_list {
    my ($self, $layout) = @_;
    my %keystrokes = (
        us => '`1234567890-=~!@#$%^&*()_+',
        fr => '²&é"(-è_çà)=~1234567890°+',
        de => '1234567890ß°!"§$%&/()=?',
        cz => ';+ěščřžýáíé=1234567890%'
    );
    return $keystrokes{$layout};
}

# post_fail_hook for upload logs for test module which uses it as base
# see https://progress.opensuse.org/issues/56636
sub post_fail_hook {
    my ($self) = shift;
    return if get_var('NOLOGS');
    select_console('log-console');
    $self->SUPER::post_fail_hook;
}

1;
