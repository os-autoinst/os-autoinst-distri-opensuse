# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle user name and password entry; check for password security
# - Check if installer is on user setup step
# - Select "Skip user creation" if ROOTONLY is defined
# - Fill user real name, username and password
# - Disable autologin if NOAUTOLOGIN is defined
# - Otherwise, if distro is sle and NOAUTOLOGIN is undefined, enable autologin
# - Select next, handle "password is too simple" screen
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use version_utils 'is_sle';
use utils;
use installation_user_settings;

sub run {
    my ($self) = @_;
    assert_screen 'inst-usersetup', 60;
    if (get_var 'ROOTONLY') {
        send_key 'alt-s';
        assert_screen 'inst-rootonly-selected';
        # done user setup
        send_key $cmd{next};
        return;
    }

    if (get_var('ASSERT_BSC1122804')) {
        # retry if not typed correctly
        my $max_tries = 4;
        my $retry = 0;
        do {
            enter_userinfo(max_interval => utils::VERY_SLOW_TYPING_SPEED);
            assert_screen([qw(inst-userinfostyped-ignore-full-name inst-userinfostyped-expected-typefaces)]);
            record_soft_failure('boo#1122804 - Typing issue with fullname') unless match_has_tag('inst-userinfostyped-expected-typefaces');
            $retry++;
        } while (($retry < $max_tries) && !match_has_tag('inst-userinfostyped-expected-typefaces'));
        assert_screen('inst-userinfostyped-expected-typefaces');    # fail if mistyped
    }
    else {
        enter_userinfo(username => 'bernhard', max_interval => utils::VERY_SLOW_TYPING_SPEED);
        assert_screen([qw(inst-userinfostyped-ignore-full-name inst-userinfostyped-expected-typefaces)]);
    }

    if (get_var('NOAUTOLOGIN') && !check_screen('autologindisabled', timeout => 0)) {
        send_key $cmd{noautologin};
        assert_screen 'autologindisabled';
    }
    elsif (is_sle() && check_var('NOAUTOLOGIN', '0')) {
        send_key $cmd{noautologin};
        assert_screen 'autologinenabled';
    }
    if (get_var('DOCRUN')) {
        send_key $cmd{otherrootpw};
        assert_screen 'rootpwdisabled';
    }

    # done user setup
    send_key $cmd{next};
    await_password_check;
}

1;
