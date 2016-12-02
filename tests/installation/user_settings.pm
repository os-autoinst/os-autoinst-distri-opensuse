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
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "inst-usersetup";
    type_string $realname;
    send_key "tab";

    send_key "tab";
    for (1 .. 2) {
        wait_screen_change { type_string "$password\t" };
    }
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

    # PW too easy (cracklib)
    if (check_var('LIVECD', 1)) {
        record_soft_failure 'boo#1013206' unless check_screen 'inst-userpasswdtoosimple';
    }
    else {
        # bsc#937012 is resolved in > SLE 12
        assert_screen 'inst-userpasswdtoosimple' unless (check_var('VERSION', '12') && check_var('ARCH', 's390x'));
    }
    send_key 'ret' if match_has_tag 'inst-userpasswdtoosimple';
}

1;
# vim: set sw=4 et:
