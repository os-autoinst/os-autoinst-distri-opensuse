# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self = shift;

    assert_screen 'release-notes', 100;    # suseconfig run
    if (get_var("ADDONS")) {
        if (check_screen 'release-notes-tab') {
            foreach $a (split(/,/, get_var('ADDONS'))) {
                if ($a eq 'smt' || check_var('FLAVOR', 'Desktop-DVD')) {
                    send_key 'alt-s';
                    assert_screen "release-notes-$a";
                    send_key 'alt-u';
                    assert_screen "release-notes-sle";
                }
                else {
                    send_key 'alt-u';
                    assert_screen "release-notes-$a";
                    send_key 'alt-s';
                    assert_screen "release-notes-sle";
                }
            }
        }
        else {
            foreach $a (split(/,/, get_var('ADDONS'))) {
                send_key 'alt-p', 1;
                if (!check_var('VIDEOMODE', 'text')) {
                    send_key ' ', 1;
                }
                send_key 'pgup',                                    1;
                send_key_until_needlematch "release-notes-list-$a", 'down';
                send_key 'ret',                                     1;
                assert_screen "release-notes-$a";
            }
            send_key 'alt-p', 1;
            if (!check_var('VIDEOMODE', 'text')) {
                send_key ' ', 1;
            }
            send_key 'pgup',                                     1;
            send_key_until_needlematch "release-notes-list-sle", 'down';
            send_key 'ret',                                      1;
            assert_screen "release-notes-sle";
        }
    }
    else {
        assert_screen "release-notes-sle";
    }
    send_key $cmd{'next'};
}

1;
