# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
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
# Summary: Process online repos during installation, relevant for openSUSE only
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils qw(:VERSION :SCENARIO);
use utils 'installwithaddonrepos_is_applicable';

sub open_online_repos_dialog {
    wait_screen_change { send_key 'alt-y' };
    assert_screen 'online-repos-configuration';
}

sub disable_online_repos_explicitly {
    open_online_repos_dialog;
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

sub run {
    # Online repos are not configurable if no network conneciton is available
    return if get_var('OFFLINE_SUT');
    ## Do not enable online repos by default
    ## List possible screens if pop-up is not there as a fallback
    my @needles = qw(online-repos-popup before-role-selection inst-networksettings partitioning-edit-proposal-button inst-instmode network-not-configured list-of-online-repositories);
    assert_screen(\@needles);

    # Do nothing if pop-up is not found
    return unless match_has_tag('online-repos-popup');

    # Test online repos dialog explicitly
    if (get_var('DISABLE_ONLINE_REPOS')) {
        disable_online_repos_explicitly;
    } elsif (installwithaddonrepos_is_applicable() && !get_var("LIVECD")) {
        # Acivate online repositories
        wait_screen_change { send_key 'alt-y' };
    } else {
        # If click No, step is skipped, which is default behavior
        wait_screen_change { send_key 'alt-n' };
    }
}

1;
