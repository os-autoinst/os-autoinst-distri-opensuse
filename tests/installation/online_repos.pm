# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Process online repos during installation, relevant for openSUSE only
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
        send_key_until_needlematch 'main-update-nos-oss-repo-disabled', 'spc', 4, 1;
        send_key 'down';
    }
    send_key_until_needlematch 'main-update-repo-disabled', 'spc', 4, 1;
    send_key 'down';
    send_key_until_needlematch 'main-repo-oss-disabled', 'spc', 4, 1;
    send_key 'down';
    send_key_until_needlematch 'main-repo-non-oss-disabled', 'spc', 4, 1;
    assert_screen 'online-repos-disabled';
    send_key $cmd{next};
}

sub run {
    # Online repos are not configurable if no network conneciton is available
    return if get_var('OFFLINE_SUT');
    ## Do not enable online repos by default
    ## List possible screens if pop-up is not there as a fallback
    my @needles = qw(online-repos-popup before-role-selection inst-networksettings partitioning-edit-proposal-button inst-instmode network-not-configured list-of-online-repositories);
    assert_screen(\@needles, timeout => 60);

    if (match_has_tag('network-not-configured')) {
        # On slow workers the network may be unconfigured - poo#87719
        send_key("alt-i");    # Edit button
        assert_screen('static-ip-address-set');
        send_key("alt-y");    # Select Dynamic address
        assert_screen('dynamic-ip-address-set');
        send_key $cmd{next};    # Next
        assert_screen('inst-networksettings');
        send_key $cmd{next};    # Next
        @needles = grep { !/inst-networksettings/ } @needles;    # Do not match the previous screen
        assert_screen(\@needles, timeout => 60);    # Check the screen again with network up and running
    }

    # Do nothing if pop-up is not found
    return unless match_has_tag('online-repos-popup');

    # Test online repos dialog explicitly
    if (get_var('DISABLE_ONLINE_REPOS')) {
        disable_online_repos_explicitly;
    } elsif (installwithaddonrepos_is_applicable()) {
        # Acivate online repositories
        wait_screen_change { send_key 'alt-y' };
    } else {
        # If click No, step is skipped, which is default behavior
        wait_screen_change { send_key 'alt-n' };
    }
}

1;
