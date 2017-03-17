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
use caasp;

sub run() {
    # poo#16408 part 1
    send_key 'alt-p';    # partitioning
    assert_screen 'prepare-hard-disk';
    send_key 'alt-b';    # back
    if (check_screen 'error-small-disk') {
        record_soft_failure 'bsc#1029291 - blocking condition can not be unblocked';
        send_key 'ret';
    }
    assert_screen 'oci-overview-filled';
    send_key 'alt-b';    # booting
    assert_screen 'inst-bootloader-settings';
    send_key 'alt-c';    # cancel
    assert_screen 'oci-overview-filled';
    send_key $cmd{next};    # network configuration
    assert_screen 'inst-networksettings';
    send_key $cmd{next};    # next
    assert_screen 'oci-overview-filled';
    send_key 'alt-k';       # kdump
    assert_screen 'inst-kdump';
    send_key 'alt-o';       # OK
    assert_screen 'oci-overview-filled';

    send_key $cmd{install};

    # Accept simple password
    handle_simple_pw;

    # Accept update repositories during installation
    if (check_var('REGISTER', 'installation')) {
        assert_screen 'registration-online-repos';
        send_key "alt-y";
    }

    # Return if disk is too small for installation
    if (check_var('FAIL_EXPECTED', 'SMALL-DISK')) {
        assert_screen 'error-small-disk';
        send_key 'ret';
        assert_screen 'oci-overview-filled';
        return;
    }

    my $repeat_once = 2;
    while ($repeat_once--) {
        # Confirm installation start
        assert_screen "startinstall";

        # poo#16408 part 2
        if ($repeat_once) {
            send_key 'alt-b';    # abort
            assert_screen 'oci-overview-filled';
        }
        send_key $cmd{install};
    }

    # We need to wait a bit for the disks to be formatted
    assert_screen "inst-packageinstallationstarted", 120;
}

1;

# vim: set sw=4 et:
