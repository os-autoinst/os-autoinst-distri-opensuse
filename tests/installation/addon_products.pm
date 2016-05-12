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
    my ($self) = @_;

    if (check_screen('network-setup', 10)) {    # won't appear for NET installs
        send_key $cmd{next};                    # use network
        assert_screen 'dhcp-network';
        send_key 'alt-d', 2;                    # DHCP
        send_key 'alt-o', 2;                    # OK
    }

    assert_screen 'addon-selection';

    if (get_var("ADDONURL")) {

        # FIXME: do the same as sle here
        foreach my $url (split(/\+/, get_var("ADDONURL"))) {
            send_key "alt-a";                   # Add another
            send_key $cmd{xnext}, 1;            # Specify URL (default)
            type_string $url;
            send_key $cmd{next}, 1;
            if (get_var("ADDONURL") !~ m{/update/}) {    # update is already trusted, so would trigger "delete"
                send_key "alt-i";
                send_key "alt-t", 1;                     # confirm import (trust) key
            }
        }
        assert_screen 'addon-selection';
        send_key $cmd{next}, 1;                          # done
    }

    if (get_var("ADDONS")) {

        for my $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-d';                            # DVD
            send_key $cmd{xnext}, 1;
            assert_screen 'dvd-selector';
            send_key_until_needlematch 'addon-dvd-list', 'tab';
            send_key_until_needlematch "addon-dvd-$a",   'down';
            send_key 'alt-o';
            if (get_var("BETA")) {
                assert_screen "addon-betawarning-$a";
                send_key "ret";
                assert_screen "addon-license-beta";
            }
            else {
                assert_screen "addon-license-$a";
            }
            sleep 2;
            send_key 'alt-y';    # yes, agree
            sleep 2;
            send_key 'alt-n';
            assert_screen 'addon-list';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $a) {
                send_key 'alt-a';
                assert_screen 'addon-selection';
            }

        }

        send_key 'alt-n';

    }
}

1;
# vim: set sw=4 et:
