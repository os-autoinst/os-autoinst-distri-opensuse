# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package x11utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_leap);

our @EXPORT = qw(
  desktop_runner_hotkey
  ensure_unlocked_desktop
  ensure_fullscreen
  handle_login
  handle_logout
  handle_relogin
  select_user_gnome
  turn_off_kde_screensaver
  turn_off_gnome_screensaver
);


sub desktop_runner_hotkey { check_var('DESKTOP', 'minimalx') ? 'super-spc' : 'alt-f2' }

# if stay under tty console for long time, then check
# screen lock is necessary when switch back to x11
# all possible options should be handled within loop to get unlocked desktop
sub ensure_unlocked_desktop {
    my $counter = 10;
    while ($counter--) {
        assert_screen [qw(displaymanager displaymanager-password-prompt generic-desktop screenlock screenlock-password)], no_wait => 1;
        if (match_has_tag 'displaymanager') {
            if (check_var('DESKTOP', 'minimalx')) {
                type_string "$username";
                save_screenshot;
            }
            if (!check_var('DESKTOP', 'gnome') || (is_sle('<15') || is_leap('<15.0'))) {
                send_key 'ret';
            }
            # On gnome, user may not be selected and using 'ret' is not enough in this case
            else {
                select_user_gnome($username);
            }
        }
        if ((match_has_tag 'displaymanager-password-prompt') || (match_has_tag 'screenlock-password')) {
            if ($password ne '') {
                type_password;
                assert_screen [qw(locked_screen-typed_password login_screen-typed_password)];
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
                    next;    # most probably screen is locked
                }
            }
            last;            # desktop is unlocked, mission accomplished
        }
        if (match_has_tag 'screenlock') {
            wait_screen_change {
                send_key 'esc';    # end screenlock
            };
        }
        wait_still_screen 2;       # slow down loop
        die 'ensure_unlocked_desktop repeated too much. Check for X-server crash.' if ($counter eq 1);    # die loop when generic-desktop not matched
    }
}

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
    my ($myuser, $user_selected) = @_;
    $myuser        //= $username;
    $user_selected //= 0;

    save_screenshot();
    # wait for DM, avoid screensaver and try to login
    send_key_until_needlematch('displaymanager', 'esc', 30, 3);
    wait_still_screen;
    if (get_var('ROOTONLY')) {
        if (check_screen 'displaymanager-username-notlisted', 10) {
            record_soft_failure 'bgo#731320/boo#1047262 "not listed" Login screen for root user is not intuitive';
            assert_and_click 'displaymanager-username-notlisted';
            wait_still_screen 3;
        }
        type_string "root\n";
    }
    elsif (match_has_tag('displaymanager-user-prompt') || get_var('DM_NEEDS_USERNAME')) {
        type_string "$myuser\n";
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
    assert_screen [qw(displaymanager-password-prompt displaymanager-focused-password-textbox)];
    if (check_var('DESKTOP', 'kde') && !match_has_tag('displaymanager-focused-password-textbox')) {
        record_soft_failure('bsc#1122664 - password textbox is not focused');
        assert_and_click 'displaymanager-password-prompt';
        assert_screen 'displaymanager-focused-password-textbox';
    }
    type_password;
    send_key "ret";
}

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
        send_key_until_needlematch 'logoutdialog', "$key";             # opens logout dialog
    }
    assert_and_click 'logout-button';                                  # press logout
}

sub handle_relogin {
    handle_logout;
    handle_login;
}

# Handle the case when user is not selected, on gnome
sub select_user_gnome {
    my ($myuser) = @_;
    $myuser //= $username;
    assert_screen [qw(displaymanager-user-selected displaymanager-user-notselected dm-nousers)];
    if (match_has_tag('displaymanager-user-notselected')) {
        assert_and_click "displaymanager-$myuser";
        record_soft_failure 'bsc#1086425- user account not selected by default, have to use mouse to login';
    }
    elsif (match_has_tag('displaymanager-user-selected')) {
        send_key 'ret';
    }
    elsif (match_has_tag('dm-nousers')) {
        type_string $myuser;
        send_key 'ret';
    }
}

sub turn_off_kde_screensaver {
    x11_start_program('kcmshell5 screenlocker', target_match => [qw(kde-screenlock-enabled screenlock-disabled)]);
    if (match_has_tag('kde-screenlock-enabled')) {
        assert_and_click('kde-disable-screenlock');
    }
    assert_screen 'screenlock-disabled';
    send_key('alt-o');
    assert_screen 'generic-desktop';
}

=head2 turn_off_gnome_screensaver

  turn_off_gnome_screensaver()

Disable screensaver in gnome. To be called from a command prompt, for example an xterm window.

=cut
sub turn_off_gnome_screensaver {
    script_run 'gsettings set org.gnome.desktop.session idle-delay 0';
}

1;
