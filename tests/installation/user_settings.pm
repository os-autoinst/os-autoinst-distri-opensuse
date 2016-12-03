# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle user name and password entry; check for password security
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use parent qw(installation_user_settings y2logsstep);
use testapi;

sub run() {
    my ($self) = @_;
    assert_screen "inst-usersetup";
    type_string $realname;
    send_key "tab";

    send_key "tab";
    $self->type_password_and_verification;
    assert_screen "inst-userinfostyped";
    if (get_var("NOAUTOLOGIN") && !check_screen('autologindisabled')) {
        send_key $cmd{noautologin};
        assert_screen "autologindisabled";
    }
    if (get_var("DOCRUN")) {
        send_key $cmd{otherrootpw};
        assert_screen "rootpwdisabled";
    }

    # done user setup
    send_key $cmd{next};
    $self->await_password_check;
}

1;
# vim: set sw=4 et:
