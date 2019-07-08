# Copyright (C) 2016-2019 SUSE LLC
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

# Summary: Test slicing 3d prints (converting STL to GCODE) using cura
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed('cura-lulzbot');
    x11_start_program('cura-lulzbot', target_match => 'cura-license-agree');
    assert_and_click "cura-license-agree";
    assert_and_click "cura-add-printer";
    assert_and_click "cura-finish";
    send_key 'ctrl-n';    # New
    assert_and_click "cura-yes";
    wait_still_screen(5);
    send_key 'ctrl-o';    # Open
    assert_screen "cura-openfiles";
    type_string "/home/$username/data/oshw_logo.stl\n";
    assert_screen "cura-oshwlogo";
    assert_screen "cura-ready", 290;
    assert_and_click "cura-file";
    assert_and_click "cura-save-as";
    assert_screen "cura-save";
    type_string "/home/$username/oshw_logo.gcode\n";
    assert_screen "cura-oshwlogo";
    send_key 'alt-f4';    # Close
    assert_screen 'generic-desktop';
    x11_start_program('xterm');
    my $gcode_size = int(script_output 'stat -c "%s" oshw_logo.gcode');
    record_info("GCODE size", "Size: $gcode_size bytes");
    send_key 'ctrl-d';
    assert_screen 'generic-desktop';
    if ($gcode_size < 200000) {
        die("GCODE file is too small");
    }
}

1;
