# Copyright (C) 2014-2019 SUSE LLC
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

# Summary: Explicitly skip SCC registration
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use strict;
use warnings;
use base "y2logsstep";

use testapi;
use registration 'skip_registration';
use utils 'assert_screen_with_soft_timeout';
use x11utils 'ensure_fullscreen';

sub run {
    assert_screen_with_soft_timeout(
        [qw(scc-registration yast2-windowborder-corner)],
        timeout      => 300,
        soft_timeout => 100,
        bugref       => 'bsc#1028774'
    );
    if (match_has_tag('yast2-windowborder-corner')) {
        if (check_var("INSTALLER_NO_SELF_UPDATE", 1)) {
            die "installer should not self-update, therefore window should not have respawned, file bug and replace this line with a soft-fail";
        }
        elsif (check_var('INSTALLER_SELF_UPDATE', 1)) {
            ensure_fullscreen(tag => 'yast2-windowborder-corner');
        }
        else {
            die
"so far this should only be reached on s390x which we test only on SLE which has self-update disabled since SLE 12 SP2 GM so we should not reach here unless this is a new version of SLE which has the self-update enabled by default";
        }
        assert_screen_with_soft_timeout(
            'scc-registration',
            timeout      => 300,
            soft_timeout => 100,
            bugref       => 'bsc#1028774'
        );
    }
    skip_registration;
}

1;
