# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select existing partition(s) for upgrade
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base "y2logsstep";
use testapi;
use utils 'assert_screen_with_soft_timeout';

sub run() {
    if (get_var('ENCRYPT')) {
        assert_screen "upgrade-unlock-disk";
        send_key 'alt-p';    # provide password
        assert_screen "upgrade-enter-password";
        type_password;
        send_key $cmd{ok};
    }

    # hardware detection and waiting for updates from suse.com can take a while
    assert_screen_with_soft_timeout('select-for-update', timeout => 500, soft_timeout => 100, bugref => 'bsc#990254');
    send_key $cmd{next}, 1;
    assert_screen "remove-repository", 240;
    send_key $cmd{next}, 1;
}

1;
# vim: set sw=4 et:
