# Copyright (C) 2018-2019 SUSE LLC
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
#
# Package: gnome-control-center vino systemd
# Summary: Test if the Screen Sharing GNOME Desktop functionality works
#   We currently need to install vino package for that
# - Launch "gnome-control-center sharing"
# - Enable sharing function
# - Install vino if necessary
#   - Relogin in case of install is necessary
#   - Redo screensharing enabling steps
# - Check if wayland is being used
#   - If wayland is detected, record_soft_failure (boo#1137569)
# - Finish with ctrl-q
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "x11test";
use strict;
use warnings;
use testapi;
use x11utils 'handle_relogin';
use version_utils 'is_tumbleweed';

sub run {
    select_console 'x11';

    # Run the gnome-control-center - the sharing section
    x11_start_program "gnome-control-center sharing", target_match => 'vino_screensharing_available-gnome-control-center-sharing';

    # Always check the common sharing functionality is enabled
    if (check_screen 'disabled_sharing') {
        assert_and_click 'disabled_sharing';
    }

    # It may happen that the screen sharing is not available
    assert_screen [qw(with_screensharing without_screensharing)];
    if (match_has_tag 'without_screensharing') {
        record_info 'vino missing', 'After the installation the screen sharing is not available - vino is missing and we need to install it now.';
        send_key 'ctrl-q';

        # Install the vino package which is probably the case of missing screen sharing option
        ensure_installed 'vino';

        # Log of and back in to ensure the vino feature gets enabled
        handle_relogin;

        # Run the gnome-control-center to ensure the same state as we were while entering this if block
        x11_start_program "gnome-control-center sharing", target_match => 'vino_screensharing_available-gnome-control-center-sharing';

        # Always check the common sharing functionality is enabled
        if (check_screen 'disabled_sharing') {
            assert_and_click 'disabled_sharing';
        }
    }

    # Ensure that screen sharing is available, on X11 only (wayland is not supported) - boo#1137569
    # (But Wayland now supported for TW after 20210119 snapshot)
    x11_start_program('xterm');
    assert_script_run("loginctl");
    my $is_wayland = (script_run('loginctl show-session $(loginctl | grep $(whoami) | awk \'{print $1 }\') -p Type | grep wayland') == 0);
    send_key 'alt-f4';
    if ($is_wayland && !is_tumbleweed) {
        assert_screen 'without_screensharing';
        record_soft_failure 'boo#1137569 - screen sharing not yet supported on wayland';
    } else {
        assert_screen 'with_screensharing';
        record_info 'vino present', 'Vino and the screen sharing are present';
    }
    send_key 'ctrl-q';
}

1;
