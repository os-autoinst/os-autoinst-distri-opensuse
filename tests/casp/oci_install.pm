# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start CaaSP installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    send_key $cmd{install};

    # Accept simple password
    assert_screen 'inst-userpasswdtoosimple';
    send_key 'ret';

    # Accept update repositories during installation
    if (check_var('REGISTER', 'installation')) {
        assert_screen 'registration-online-repos';
        send_key "alt-y";
    }

    # Confirm installation start
    assert_screen "startinstall";
    send_key $cmd{install};

    # We need to wait a bit for the disks to be formatted
    assert_screen "inst-packageinstallationstarted", 120;
}

1;

# vim: set sw=4 et:
