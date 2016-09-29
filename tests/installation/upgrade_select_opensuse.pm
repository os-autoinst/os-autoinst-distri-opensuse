# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Split openSUSE specific part from upgrade_select
# G-Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use strict;
use base "y2logsstep";
use testapi;

# Check that installer does not freeze when pressing next
sub check_bsc997635 {
    if (!wait_screen_change { send_key $cmd{next} }, 10) {
        record_soft_failure 'bsc#997635';
        sleep 30;
    }
}

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
        if (check_screen('upgrade-license-agreement')) {
            check_bsc997635;
        }
    }

    if (check_screen('installed-product-incompatible', 10)) {
        send_key 'alt-o';    # C&ontinue
        record_soft_failure 'installed product incompatible';
    }

    assert_screen "update-installation-overview", 60;
}

1;
# vim: set sw=4 et:
