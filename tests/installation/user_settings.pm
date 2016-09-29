# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: restructure opensuse install test code
#    this splits monolitic yast1b and yast2 modules
#    into finer grained single-task modules
# G-Maintainer: Bernhard M. Wiedemann <bernhard+osautoinst lsmod de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # user setup
    assert_screen "inst-usersetup";
    type_string $realname;
    send_key "tab";

    send_key "tab";
    for (1 .. 2) {
        type_string "$password\t";
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

    # loading cracklib
    # If check_screen added to workaround bsc#937012
    if (check_screen('inst-userpasswdtoosimple', 13)) {
        send_key "ret";
    }
    else {
        record_soft_failure 'bsc#937012';
    }
}

1;
# vim: set sw=4 et:
