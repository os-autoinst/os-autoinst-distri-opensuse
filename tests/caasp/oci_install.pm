# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start CaaSP installation
# Maintainer: Martin Kravec <mkravec@suse.com>, Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use caasp;
use version_utils 'is_caasp';

# poo#16408
sub run {
    # Partitioning
    send_alt 'partitioning';
    if (is_caasp '=4.0') {
        record_soft_failure 'bsc#1099485 - Jumping straight to expert partitioner';
        assert_screen 'expert-partitioner';
    }
    else {
        assert_screen 'prepare-hard-disk';
    }
    send_key 'alt-b';    # back
    if (check_var('FAIL_EXPECTED', 'SMALL-DISK')) {
        assert_screen 'error-small-disk';
        send_key 'ret';
    }
    assert_screen 'rootpassword-typed';

    # Booting
    send_alt 'booting';
    assert_screen 'inst-bootloader-settings';
    send_key 'alt-c';
    assert_screen 'rootpassword-typed';

    # Network configuration
    send_alt 'network';
    assert_screen 'inst-networksettings';
    send_key 'alt-n';
    assert_screen 'rootpassword-typed';

    # Kdump
    send_alt 'kdump';
    assert_screen 'inst-kdump';
    send_key 'alt-o';
    assert_screen 'rootpassword-typed';

    send_alt 'install';

    # Accept simple password
    handle_simple_pw;

    # Accept update repositories during installation
    if (check_var('REGISTER', 'installation')) {
        assert_screen 'registration-online-repos', 60;
        send_key "alt-y";
    }

    # Return if disk is too small for installation
    if (check_var('FAIL_EXPECTED', 'SMALL-DISK')) {
        assert_screen 'error-small-disk';
        send_key 'ret';
        assert_screen 'rootpassword-typed';
        return;
    }

    my $repeat_once = 2;
    while ($repeat_once--) {
        # Confirm installation start
        assert_screen "startinstall";

        if ($repeat_once) {
            send_key 'alt-b';
            sleep 5 if check_var('VIDEOMODE', 'text');    # Wait until DOM reloads data tree
            assert_screen 'rootpassword-typed';
        }
        elsif (is_caasp '3.0+') {
            # accept eula
            send_key 'alt-a';
        }

        send_alt 'install';
    }

    # We need to wait a bit for the disks to be formatted
    assert_screen "inst-packageinstallationstarted", 120;
}

1;

