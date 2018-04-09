# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
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
# Summary: Disable online repos during installation
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use base "y2logsstep";
use testapi;
use version_utils 'is_leap';

sub run {
    assert_screen 'desktop-selection';
    send_key 'alt-o';    # press configure online repos button
    assert_screen 'online-repos-configuration';
    send_key 'alt-u';    # navigate to the List

    # Disable repos
    if (is_leap) {
        # We have update non-oss repo on leap
        send_key_until_needlematch 'main-update-nos-oss-repo-disabled', 'spc', 3, 1;
        send_key 'down';
    }
    send_key_until_needlematch 'main-update-repo-disabled', 'spc', 3, 1;
    send_key 'down';
    send_key_until_needlematch 'main-repo-oss-disabled', 'spc', 3, 1;
    send_key 'down';
    send_key_until_needlematch 'main-repo-non-oss-disabled', 'spc', 3, 1;
    assert_screen 'online-repos-disabled';
    send_key $cmd{next};
}

1;
