# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package x11utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_leap);
use utils 'assert_and_click_until_screen_change';
use Utils::Architectures;
use Utils::Backends qw(is_pvm is_qemu);

our @EXPORT = qw(
  desktop_runner_hotkey
  ensure_unlocked_desktop
  ensure_fullscreen
  handle_additional_polkit_windows
  handle_login
  handle_logout
  handle_relogin
  handle_welcome_screen
  select_user_gnome
  turn_off_screensaver
  turn_off_kde_screensaver
  turn_off_plasma_tooltips
  turn_off_plasma_screen_energysaver
  turn_off_plasma_screenlocker
  turn_off_gnome_screensaver
  turn_off_gnome_screensaver_for_gdm
  turn_off_gnome_screensaver_for_running_gdm
  turn_off_gnome_suspend
  turn_off_gnome_show_banner
  untick_welcome_on_next_startup
  start_root_shell_in_xterm
  x11_start_program_xterm
  handle_gnome_activities
);

=head1 X11_UTILS

=head1 SYNOPSIS

 use lib::x11utils;

=cut

=head2 desktop_runner_hotkey

 desktop_runner_hotkey();

Returns the hotkey for the desktop runner according to the used
desktop

=cut

sub desktop_runner_hotkey { check_var('DESKTOP', 'minimalx') ? 'ctrl-alt-spc' : 'alt-f2' }


=head2

 ensure_unlocked_desktop();

if stay under tty console for long time, then check
screen lock is necessary when switch back to x11
all possible options should be handled within loop to get unlocked desktop

=cut

sub ensure_unlocked_desktop {
    my $counter = 10;

    # press key to update screen, wait shortly before and after to not match cached screen
    my $wait_time = get_var('UPGRADE') ? 10 : 3;
    wait_still_screen($wait_time, timeout => 15);
    send_key 'ctrl';
    wait_still_screen($wait_time, timeout => 15);
    while ($counter--) {
        my @tags = qw(displaymanager displaymanager-password-prompt generic-desktop screenlock screenlock-password authentication-required-user-settings authentication-required-modify-system guest-disabled-display oh-no-something-has-gone-wrong);
        push(@tags, 'blackscreen') if get_var("DESKTOP") =~ /minimalx|xfce/;    # Only xscreensaver and xfce have a blackscreen as screenlock
        push(@tags, 'gnome-activities') if check_var('DESKTOP', 'gnome');
        push(@tags, 'gnome-activities') if (!check_var('DESKTOP', 'gnome') && get_var("FIPS_ENABLED") && is_pvm);
        # For PowerVM x11 access in FIPS mode, we can connect it via vnc even in textmode
        # Add some wait time for PowerVM due to performance issue
        my $timeout = is_pvm ? '120' : '30';
        assert_screen(\@tags, timeout => $timeout, no_wait => 1);
        # Starting with GNOME 40, upon login, the activities screen is open (assuming the
        # user will want to start something. For openQA, we simply press 'esc' to close
        # it again and really end up on the desktop
        if (match_has_tag('gnome-activities')) {
            send_key 'esc';
            # Send the key 'esc' again on PowerVM setup to make sure it can switch to generic desktop
            if (get_var("FIPS_ENABLED") && is_pvm) {
                send_key 'esc';
                wait_still_screen 5;
            }
            @tags = grep { !/gnome-activities/ } @tags;
        }
        if (match_has_tag 'oh-no-something-has-gone-wrong') {
            # bsc#1159950 - gnome-session-failed is detected
            # Note: usually happens on *big* hardware with lot of cpus/memory
            record_soft_failure 'bsc#1159950 - [Build 108.1] openQA test fails in first_boot - gnome-session-failed is detected';
            select_console 'root-console';    # Workaround command should be executed on a root console
            script_run 'kill $(ps -ef | awk \'/[g]nome-session-failed/ { print $2 }\')';
            select_console 'x11', await_console => 0;    # Go back to X11
        }
        if (match_has_tag 'displaymanager') {
            if (check_var('DESKTOP', 'minimalx')) {
                type_string "$username";
                save_screenshot;
            }
            # Always select user if DM_NEEDS_USERNAME is set
            if ((!check_var('DESKTOP', 'gnome') || (is_sle('<15') || is_leap('<15.0'))) && !get_var('DM_NEEDS_USERNAME')) {
                send_key 'ret';
            }
            # On gnome, user may not be selected and using 'ret' is not enough in this case
            else {
                select_user_gnome($username);
            }
        }
        if (match_has_tag('guest-disabled-display')) {
            wait_screen_change(sub {
                    send_key 'shift';
            }, 10);
            record_info('Guest disabled display', 'Might be consequence of bsc#1168979');
        }
        if (match_has_tag('authentication-required-user-settings') || match_has_tag('authentication-required-modify-system')) {
            wait_still_screen;    # Check again as the pop-up may be just a glitch, see bsc#1168979
            if (check_screen([qw(authentication-required-user-settings authentication-required-modify-system)])) {
                if (is_sle('>=15-SP4') || is_leap('>=15.4')) {
                    # auth window needs focus before typing passoword for GNOME40+
                    assert_and_click('auth-window-password-prompt');
                }
                type_password;
                assert_and_click "authenticate";
            } else {
                record_soft_failure "bsc#1168979 - screenbuffer not updated after screen is locked";
                next;
            }
        }
        if ((match_has_tag 'displaymanager-password-prompt') || (match_has_tag 'screenlock-password')) {
            if ($password ne '') {
                type_password;
                # poo#97556
                if (check_var('DESKTOP', 'minimalx')) {
                    send_key 'ret';
                    wait_still_screen;
                }
                assert_screen([qw(locked_screen-typed_password login_screen-typed_password generic-desktop)], timeout => 150);
                next if match_has_tag 'generic-desktop';
            }
            send_key 'ret';
        }
        if (match_has_tag 'generic-desktop') {
            send_key 'esc';
            unless (get_var('DESKTOP', '') =~ m/awesome|enlightenment|lxqt/) {
                # gnome/mate/minimalx might show the old 'generic desktop' screen although that is
                # just a left over in the framebuffer but actually the screen is
                # already locked so we have to try something else to check
                # responsiveness.
                # open run command prompt (if screen isn't locked)
                mouse_hide(1);
                send_key desktop_runner_hotkey;
                if (check_screen 'desktop-runner', 30) {
                    send_key 'esc';
                    assert_screen 'generic-desktop';
                }
                else {
                    diag("Next loop ($counter), Generic desktop didn't match");
                    record_info('Screen seems frozen', 'Might be consequence of bsc#1168979') if is_aarch64;
                    next;    # most probably screen is locked
                }
            }
            last;    # desktop is unlocked, mission accomplished
        }
        die 'ensure_unlocked_desktop repeated too much. Check for X-server crash.' if ($counter eq 1);    # die loop when generic-desktop not matched
        if (match_has_tag('screenlock') || match_has_tag('blackscreen')) {
            wait_screen_change {
                if (is_qemu && (is_sle('=15-sp3') || is_sle('=15-sp2'))) {
                    # sometimes screensaver can't be unlocked with key presses poo#125930
                    mouse_set(600, 600);
                    mouse_click;
                    mouse_hide(1);
                }
                else {
                    # ESC of KDE turns the monitor off and CTRL does not work on older SLES versions to unlock the screen
                    send_key(is_sle("<15-SP4") ? 'esc' : 'ctrl');    # end screenlock
                }
                diag("Screen lock present");
            };
            next;    # Go directly to assert_screen, skip wait_still_screen (and don't collect $200)
        }
        wait_still_screen 1;    # slow down loop
    }
}

=head2 ensure_fullscreen

 ensure_fullscreen($tag);

C<tag> can contain a needle name and is optional, it defaults to yast2-windowborder

=cut

sub ensure_fullscreen {
    my (%args) = @_;
    $args{tag} //= 'yast2-windowborder';
    # for ssh-X using our window manager we need to handle windows explicitly
    if (check_var('VIDEOMODE', 'ssh-x')) {
        assert_screen($args{tag});
        my $console = select_console("installation");
        $console->fullscreen({window_name => 'YaST2*'});
    }
}

sub handle_additional_polkit_windows {
    my $mypwd = shift // $testapi::password;
    if (match_has_tag('authentication-required-user-settings')) {
        # for S390x testing, since they are not using qemu built-in vnc, it is
        # expected that polkit authentication window can open for first time login.
        # see bsc#1177446 for more information.
        # Base latest feedback of bsc#1192992,authentication should never open if is_sle  >= 15SP4
        if (is_sle('>=15-sp4')) {
            record_soft_failure 'bsc#1192992 - authentication should never open if is_sle >= 15SP4';
        } else {
            record_info('authentication open for first time login');
        }
        wait_still_screen(5);
        my $counter = 5;
        while (check_screen('authentication-required-user-settings', 10) && $counter) {
            type_password($mypwd);
            send_key 'ret';
            wait_still_screen(2, 4);
            $counter--;
            if ($counter < 4) {
                record_soft_failure 'bsc#1192992 - multiple authentication due to repositories refresh on s390x';
            }
        }
    }
    if (match_has_tag('authentication-required-modify-system')) {
        type_password($mypwd);
        send_key 'ret';
        wait_still_screen(2, 4);
    }
}

=head2 handle_login

 handle_login($myuser, $user_selected);

Log the user in using the displaymanager.
When C<$myuser> is set, this user will be used for login.
Otherwise the function will default to C<$username>.
For displaymanagers (like gnome) where the user needs to be selected
from a menu C<$user_selected> tells the function that the desired
user has already been selected before this function was called.

Example:

  handle_login('user1', 1);

=cut

sub handle_login {
    my ($myuser, $user_selected, $mypwd) = @_;
    $myuser //= $username;
    $mypwd //= $testapi::password;
    $user_selected //= 0;

    save_screenshot();
    # wait for DM, avoid screensaver and try to login
    # Previously this pressed esc, but that makes the text field in SDDM lose focus
    # we need send key 'esc' to quit screen saver when desktop is gnome
    my $mykey = check_var('DESKTOP', 'gnome') ? 'esc' : 'shift';
    send_key_until_needlematch('displaymanager', $mykey, 31, 3);
    if (get_var('ROOTONLY')) {
        # we now use this tag to support login as root
        if (check_screen 'displaymanager-username-notlisted', 10) {
            record_info 'bgo#731320/boo#1047262 "not listed" Login screen for root user is not intuitive';
            assert_and_click 'displaymanager-username-notlisted';
            wait_still_screen 3;
        }
        enter_cmd "root";
    }
    elsif (match_has_tag('displaymanager-user-prompt') || get_var('DM_NEEDS_USERNAME')) {
        enter_cmd "$myuser";
    }
    elsif (check_var('DESKTOP', 'gnome')) {
        if ($user_selected || (is_sle('<15') || is_leap('<15.0'))) {
            send_key 'ret';
        }
        # DMs in condition above have to select user
        else {
            select_user_gnome($myuser);
        }
    }
    assert_screen 'displaymanager-password-prompt';
    type_password($mypwd);
    send_key 'ret';
    wait_still_screen;
    handle_additional_polkit_windows($mypwd) if check_screen([qw(authentication-required-user-settings authentication-required-modify-system)], 15);
    assert_screen([qw(generic-desktop gnome-activities opensuse-welcome)], 180);
    if (match_has_tag('gnome-activities')) {
        send_key_until_needlematch [qw(generic-desktop opensuse-welcome)], 'esc', 5, 10;
    }
}

=head2 handle_logout

 handle_logout();

Handles the logout from the desktop

=cut

sub handle_logout {
    # hide mouse for clean logout needles
    mouse_hide();
    # logout
    if (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'lxde')) {
        my $command = check_var('DESKTOP', 'gnome') ? 'gnome-session-quit' : 'lxsession-logout';
        my $target_match = check_var('DESKTOP', 'gnome') ? undef : 'logoutdialog';
        x11_start_program($command, target_match => $target_match);    # opens logout dialog
    }
    else {
        my $key = check_var('DESKTOP', 'xfce') ? 'alt-f4' : 'ctrl-alt-delete';
        send_key_until_needlematch 'logoutdialog', "$key";    # opens logout dialog
    }
    assert_and_click 'logout-button';    # press logout
}

=head2 handle_relogin

 handle_relogin();

First logs out and the log in via C<handle_logout()> and C<handle_login()>

=cut

sub handle_relogin {
    handle_logout;
    handle_login;
}

=head2 select_user_gnome

 select_user_gnome([$myuser]);

Handle the case when user is not selected in login screen, on gnome.
C<$myuser> specifies the username to switch to.
If not set, it will default to C<$username>.

=cut

sub select_user_gnome {
    my ($myuser) = @_;
    $myuser //= $username;
    assert_screen [qw(displaymanager-user-selected displaymanager-user-notselected dm-nousers)];
    if (match_has_tag('displaymanager-user-notselected')) {
        assert_and_click "displaymanager-$myuser";
    }
    elsif (match_has_tag('displaymanager-user-selected')) {
        if ($myuser =~ 'bernhard') {
            send_key 'ret';
            # sometimes the system is slow, need wait several seconds for the screen to change.
            wait_still_screen 5 if is_s390x;
        }
        else {
            assert_and_click "displaymanager-$myuser";
        }
    }
    elsif (match_has_tag('dm-nousers')) {
        type_string $myuser;
        send_key 'ret';
    }
}

=head2 turn_off_plasma_screen_energysaver

 turn_off_plasma_screen_energysaver()

Turns off the Plasma desktop screen energy saving.

=cut

sub turn_off_plasma_screen_energysaver {
    x11_start_program('kcmshell5 powerdevilprofilesconfig', target_match => [qw(kde-energysaver-enabled energysaver-disabled)]);
    assert_and_click 'kde-disable-energysaver' if match_has_tag('kde-energysaver-enabled');
    assert_screen 'kde-energysaver-disabled';
    # Was 'alt-o' before, but does not work in Plasma 5.17 due to kde#411758
    send_key 'ctrl-ret';
    assert_screen 'generic-desktop';
}

=head2 turn_off_plasma_screenlocker

 turn_off_plasma_screenlocker()

Turns off the Plasma desktop screenlocker.

=cut

sub turn_off_plasma_screenlocker {
    x11_start_program('kcmshell5 screenlocker', target_match => [qw(kde-screenlock-enabled screenlock-disabled)]);
    assert_and_click 'kde-disable-screenlock' if match_has_tag('kde-screenlock-enabled');
    assert_screen 'screenlock-disabled';
    # Was 'alt-o' before, but does not work in Plasma 5.17 due to kde#411758
    send_key 'ctrl-ret';
    assert_screen 'generic-desktop';
}

=head2 turn_off_plasma_tooltips

  turn_off_plasma_tooltips()

Disable Plasma tooltips, especially the one triggered by the "Peek Desktop" below the default
mouse_hide location can break needles and break or slow down matches.

=cut

sub turn_off_plasma_tooltips {
    x11_start_program('kwriteconfig5 --file plasmarc --group PlasmaToolTips --key Delay -- -1',
        target_match => 'generic-desktop', no_wait => 1) if check_var('DESKTOP', 'kde');
}

=head2 turn_off_kde_screensaver

  turn_off_kde_screensaver()

Prevents screen from being locked or turning black while using the Plasma
desktop. Call before tests that are not providing input for a long time, to
prevent needles from failing.

=cut

sub turn_off_kde_screensaver {
    turn_off_plasma_screenlocker;
    turn_off_plasma_screen_energysaver;
}

=head2 turn_off_gnome_screensaver

  turn_off_gnome_screensaver()

Disable screensaver in gnome. To be called from a command prompt, for example an xterm window.

=cut

sub turn_off_gnome_screensaver {
    script_run 'gsettings set org.gnome.desktop.session idle-delay 0', die_on_timeout => 0, timeout => 90;
}

=head2 turn_off_gnome_screensaver_for_gdm

turn_off_gnome_screensaver_for_gdm()

Disable screensaver in gnome for gdm. The function should be run under root. To be called from
a command prompt, for example an xterm window.

=cut

sub turn_off_gnome_screensaver_for_gdm {
    script_run 'sudo -u gdm dbus-launch gsettings set org.gnome.desktop.session idle-delay 0';
}

=head2 turn_off_gnome_screensaver_for_running_gdm

turn_off_gnome_screensaver_for_running_gdm()

Disable screensaver in gnome for running gdm. The function should be run under root. To be called
from a command prompt, for example an xterm window.

=cut

sub turn_off_gnome_screensaver_for_running_gdm {
    script_run 'su gdm -s /bin/bash -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u gdm)/bus gsettings set org.gnome.desktop.session idle-delay 0"';
}

=head2 turn_off_gnome_suspend

  turn_off_gnome_suspend()

Disable suspend in gnome. To be called from a command prompt, for example an xterm window.

=cut

sub turn_off_gnome_suspend {
    script_run 'gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type \'nothing\'';
}

=head2 turn_off_screensaver

 turn_off_screensaver();

Turns off the screensaver depending on desktop environment

=cut

sub turn_off_screensaver {
    return turn_off_kde_screensaver if check_var('DESKTOP', 'kde');
    die "Unsupported desktop '" . get_var('DESKTOP', '') . "'" unless check_var('DESKTOP', 'gnome');
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    script_run 'exit', 0;
}

# turn off the gnome deskop's notification
sub turn_off_gnome_show_banner {
    script_run 'gsettings set org.gnome.desktop.notifications show-banners false';
}

=head2 untick_welcome_on_next_startup

 untick_welcome_on_next_startup();

untick welcome page on next startup.

=cut

sub untick_welcome_on_next_startup {
    # Untick box - (Retries may be needed: poo#56024)
    for my $retry (1 .. 5) {
        assert_and_click_until_screen_change("opensuse-welcome-show-on-boot", 5, 5);
        # Moving the cursor already causes screen changes - do not fail the check
        # immediately but allow some time to reach the final state
        last if check_screen("opensuse-welcome-show-on-boot-unselected", timeout => 5);
        die "Unable to untick 'Show on next startup'" if $retry == 5;
    }
    for my $retry (1 .. 5) {
        send_key 'alt-f4';
        last if check_screen("generic-desktop", timeout => 5);
        die "Unable to close openSUSE Welcome screen" if $retry == 5;
    }
}

=head2 handle_welcome_screen

 handle_welcome_screen([timeout => $timeout]);

openSUSE Welcome window should be auto-launched.
Disable auto-launch on next boot and close application.
Also handle workarounds when needed.

=cut

sub handle_welcome_screen {
    my (%args) = @_;
    assert_screen([qw(opensuse-welcome opensuse-welcome-gnome40-activities)], $args{timeout});
    send_key 'esc' if match_has_tag('opensuse-welcome-gnome40-activities');
    untick_welcome_on_next_startup;
}

=head2 start_root_shell_in_xterm

    start_root_shell_in_xterm()
    
Start a root shell in xterm.

=cut

sub start_root_shell_in_xterm {
    select_console 'x11';
    x11_start_program("xterm -geometry 155x50+5+5", target_match => 'xterm');
    # Verification runs for poo#102557 showed that the terminal window does not get focus,
    # so we click into it.
    mouse_set(400, 400);
    mouse_click(['left']);
    become_root;
}

=head2 x11_start_program_xterm

    x11_start_program_xterm()

Start xterm, if it is not focused, record a soft-failure and focus the xterm window.

=cut

sub x11_start_program_xterm {
    x11_start_program('xterm', target_match => [qw(xterm xterm-without-focus)]);
    if (match_has_tag 'xterm-without-focus') {
        record_soft_failure('poo#111752: xterm is not focused');
        click_lastmatch;
        assert_screen 'xterm';
    }
}

=head2 handle_gnome_activities

    handle_gnome_activities()

handle_gnome_activities
=cut

sub handle_gnome_activities {
    my @tags = 'generic-desktop';
    my $timeout = 600;

    push(@tags, 'gnome-activities') if check_var('DESKTOP', 'gnome');

    assert_screen \@tags, $timeout;
    # Starting with GNOME 40, upon login, the activities screen is open (assuming the
    # user will want to start something. For openQA, we simply press 'esc' to close
    # it again and really end up on the desktop
    if (match_has_tag('gnome-activities')) {
        send_key 'esc';
        @tags = grep { !/gnome-activities/ } @tags;
        assert_screen \@tags, $timeout;
    }
}

1;
