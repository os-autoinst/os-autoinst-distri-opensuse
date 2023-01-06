# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select and install product addons based on test variables
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    if (check_screen('network-setup', 10)) {    # won't appear for NET installs
        send_key $cmd{next};    # use network
        assert_screen 'dhcp-network';
        wait_screen_change { send_key 'alt-d' };    # DHCP
        send_key 'alt-o';    # OK
    }

    assert_screen 'addon-selection';

    if (get_var("ADDONURL")) {

        # FIXME: do the same as sle here
        foreach my $url (split(/\+/, get_var("ADDONURL"))) {
            send_key "alt-a";    # Add another
            send_key $cmd{xnext};    # Specify URL (default)
            wait_still_screen(1);
            type_string $url;
            wait_screen_change { send_key $cmd{next} };
            if (get_var("ADDONURL") !~ m{/update/}) {    # update is already trusted, so would trigger "delete"
                send_key "alt-i";
                assert_screen 'import-untrusted-gpg-key-598D0E63B3FD7E48';
                send_key "alt-t";    # confirm import (trust) key
            }
        }
        assert_screen 'addon-selection';
        wait_screen_change { send_key $cmd{next} };    # done
    }

    if (get_var("ADDONS")) {

        for my $i (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-d';    # DVD
            send_key $cmd{xnext};
            assert_screen 'dvd-selector';
            send_key_until_needlematch 'addon-dvd-list', 'tab';
            send_key_until_needlematch "addon-dvd-$i", 'down';
            send_key 'alt-o';
            if (get_var("BETA")) {
                assert_screen "addon-betawarning-$i";
                send_key "ret";
                assert_screen "addon-license-beta";
            }
            else {
                assert_screen "addon-license-$i";
            }
            wait_screen_change { send_key 'alt-y' };    # yes, agree
            send_key $cmd{next};
            assert_screen 'addon-list';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $i) {
                send_key 'alt-a';
                assert_screen 'addon-selection';
            }
        }
        send_key $cmd{next};
    }
}

1;
