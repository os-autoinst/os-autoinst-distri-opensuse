# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub run() {
    assert_screen 'additional-products';
    send_key 'alt-p';
    for my $addon (split(/,/, get_var('DUD_ADDONS'))) {
        my $uc_addon = uc $addon;                                           # variable name is upper case
        if (get_var("BETA_$uc_addon")) {
            assert_screen "addon-betawarning-$addon";
            send_key "ret";
            assert_screen "addon-license-beta";
        }
        else {
            assert_screen "addon-license-$addon";
        }
        if (get_var("HASLICENSE")) {
            if (check_screen 'next-button-is-active', 5) {
                send_key $cmd{next};
                assert_screen "license-refuse";
                send_key 'alt-n';    # no, don't refuse agreement
                wait_still_screen 2;
                send_key $cmd{accept};    # accept license
            }
            else {
                wait_still_screen 2;
                send_key $cmd{accept};    # accept license
            }
        }
        wait_still_screen 2;
        send_key $cmd{next};
    }
}

1;
# vim: sw=4 et
