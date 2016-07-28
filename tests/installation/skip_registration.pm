# Copyright (C) 2014,2015 SUSE Linux GmbH
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

use strict;
use base "y2logsstep";

use testapi;
use registration;
use utils qw/ensure_fullscreen assert_screen_with_soft_timeout/;

sub run() {
    assert_screen_with_soft_timeout([qw/scc-registration yast2-windowborder-corner/], timeout => 300, soft_timeout => 100, bugref => 'bsc#990254');
    if (match_has_tag('yast2-windowborder-corner')) {
        if (check_var("INSTALLER_NO_SELF_UPDATE", 1)) {
            die "installer should not self-update, therefore window should not have respawned, file bug and replace this line by record_soft_failure";
        }
        ensure_fullscreen(tag => 'yast2-windowborder-corner');
        assert_screen_with_soft_timeout('scc-registration', timeout => 300, soft_timeout => 100, bugref => 'bsc#990254');
    }
    send_key "alt-s", 1;    # skip SCC registration
    assert_screen([qw/scc-skip-reg-warning-yes scc-skip-reg-warning-ok scc-skip-reg-no-warning/]);
    if (match_has_tag('scc-skip-reg-warning-ok')) {
        send_key "alt-o";    # confirmed skip SCC registration
        wait_still_screen;
        send_key "alt-n";    # next
    }
    elsif (match_has_tag('scc-skip-reg-warning-yes')) {
        send_key "alt-y";    # confirmed skip SCC registration
    }
    else {
        # no warning showed up
    }
}

1;
# vim: set sw=4 et:
