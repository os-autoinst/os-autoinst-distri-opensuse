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
    my $self = shift;

    if (get_var("UPGRADE") && get_var("ADDONS")) {    # Netwrok setup
        if (check_screen('network-setup', 10)) {      # won't appear for NET installs
            send_key $cmd{"next"};                    # use network
            assert_screen 'dhcp-network';
            send_key 'alt-d';                         # DHCP
            send_key "alt-o", 2;                      # OK
        }
    }

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1;
    assert_screen 'previously-used-repositories', 5;
    if (!check_var('ADDONS', 'smt')) {
        send_key $cmd{"next"}, 1;
    }

    if (get_var("UPGRADE") && get_var("ADDONS")) {
        foreach $a (split(/,/, get_var('ADDONS'))) {
            if ($a eq 'smt') {
                send_key_until_needlematch 'used-repo-list',    'tab',   5;    # enable SMT repository
                send_key_until_needlematch 'smt-repo-selected', 'down',  5;
                send_key_until_needlematch 'used-smt-enabled',  'alt-t', 5;
                send_key $cmd{"next"}, 1;
                if (check_screen('network-not-configured', 5)) {
                    send_key 'ret', 1;                                         # Yes
                    send_key $cmd{"next"};                                     # use network
                    assert_screen 'dhcp-network';
                    send_key 'alt-d';                                          # DHCP
                    send_key "alt-o", 2;                                       # OK
                }
                record_soft_failure                                            # https://bugzilla.suse.com/show_bug.cgi?id=928895
                  assert_screen 'correct-media';                               # Correct media request
                send_key "alt-o", 2;                                           # OK
            }
            else {
                send_key 'alt-d';                                              # DVD
                send_key $cmd{"xnext"}, 1;
                assert_screen 'dvd-selector',                3;
                send_key_until_needlematch 'addon-dvd-list', 'tab', 10;
                send_key_until_needlematch "addon-dvd-$a",   'down', 10;
                send_key 'alt-o';
                if (get_var("BETA")) {
                    assert_screen "addon-betawarning-$a", 10;
                    send_key "ret";
                    assert_screen "addon-license-beta", 10;
                }
                else {
                    assert_screen "addon-license-$a", 10;
                }
                sleep 2;
                send_key 'alt-y';    # yes, agree
                sleep 2;
                send_key 'alt-n';
                assert_screen 'addon-list';
                if ((split(/,/, get_var('ADDONS')))[-1] ne $a) {
                    send_key 'alt-a';
                    assert_screen 'addon-selection', 15;
                }
            }
        }
        if (!check_var('ADDONS', 'smt')) {    # no add-on list for SMT
            assert_screen 'addon-list', 5;
            send_key $cmd{"next"}, 1;
        }
    }
    else {
        send_key $cmd{"next"}, 1;
    }

    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
