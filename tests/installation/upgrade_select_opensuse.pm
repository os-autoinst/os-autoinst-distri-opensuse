# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    # offline DVD upgrade may not have network (boo#995771)
    if (!check_var("FLAVOR", "NET") && check_screen('network-not-configured')) {
        send_key $cmd{next};
        assert_screen('ERROR-cannot-download-repositories');
        send_key 'alt-o';
    }
    else {
        assert_screen('list-of-online-repositories', 10);
        send_key $cmd{next};

        if (get_var("BETA")) {
            assert_screen "inst-betawarning";
            send_key 'alt-o';
        }
        # Bug 881107 - there is 2nd license agreement screen in openSUSE upgrade
        # http://bugzilla.opensuse.org/show_bug.cgi?id=881107
        if (check_screen('upgrade-license-agreement', 10)) {
            send_key 'alt-n';
        }
    }

    if (check_screen('installed-product-incompatible', 10)) {
        send_key 'alt-o';    # C&ontinue
        record_soft_failure 'installed product incompatible';
    }

    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
