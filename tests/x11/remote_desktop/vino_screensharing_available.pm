# Copyright (C) 2018 SUSE LLC
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
# Summary: Test if the Screen Sharing GNOME Desktop functionality works
#   We currently need to install vino package for that
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "x11test";
use strict;
use testapi;
use utils;

sub run {
    # Run the gnome-control-center - the sharing section
    x11_start_program("gnome-control-center sharing", target_match => 'vino_screensharing_available-gnome-control-center-sharing');

    # It may happen that the screen sharing is not available
    assert_screen [qw(with_screensharing without_screensharing disabled_screensharing)];
    if (match_has_tag 'without_screensharing') {
        record_info 'vino missing', 'After the installation the screen sharing is not available - vino is missing and we need to install it now.';
        send_key 'ctrl-q';

        # Install the vino package which is probably the case of missing screen sharing option
        ensure_installed 'vino';

        handle_relogin;

        # Run the gnome-control-center to ensure the same state as we were while entering this if block
        x11_start_program("gnome-control-center sharing", target_match => 'vino_screensharing_available-gnome-control-center-sharing');
    }
    if (match_has_tag 'disabled_screensharing') {
        assert_and_click 'disabled_screensharing';
    }

    # Finally ensure that the screen sharing is available
    assert_screen 'with_screensharing';
    record_info 'vino present', 'Vino and the screen sharing are present';
    send_key 'ctrl-q';
}

1;
