# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle user name and password entry; check for password security
# - Check if installer is on user setup step
# - Select "Skip user creation" if ROOTONLY is defined
# - Fill user real name, username and password
# - Disable autologin if NOAUTOLOGIN is defined
# - Otherwise, if distro is sle and NOAUTOLOGIN is undefined, enable autologin
# - Select next, handle "password is too simple" screen
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use parent qw(installation_user_settings y2_installbase);
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    assert_screen 'inst-usersetup';
    if (get_var 'ROOTONLY') {
        send_key 'alt-s';
        assert_screen 'inst-rootonly-selected';
        # done user setup
        send_key $cmd{next};
        return;
    }

    $self->enter_userinfo();
    assert_screen 'inst-userinfostyped';
    if (match_has_tag 'boo#1122804') {
        diag "trying again with slow typing due to https://progress.opensuse.org/issues/46190\n";
        $self->enter_userinfo(retry => 1);
        assert_screen 'inst-userinfostyped';
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
    $self->await_password_check;
}

1;
