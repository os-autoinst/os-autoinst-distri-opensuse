#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen 'inst-addon', 3;
    if ( get_var("ADDONS")) {
        send_key 'alt-k';   # install with addons
        foreach $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-d';   # DVD
            send_key 'alt-n', 3;
            assert_screen 'dvd-selector', 3;
            $self->key_round('addon-dvd-list', 'tab', 10);  # jump into addon list
            $self->key_round("addon-dvd-$a", 'down', 10);   # select addon in list
            send_key 'alt-o';   # continue
            if (get_var("BETA")) {
                assert_screen "addon-betawarning-$a", 10;
                send_key "ret";
                assert_screen "addon-license-beta", 10;
            }
            else {
                assert_screen "addon-license-$a", 10;
            }
            sleep 2;
            send_key 'alt-a';   # yes, agree
            sleep 2;
            send_key 'alt-n';   # next
            assert_screen 'addon-list';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $a) {
                send_key 'alt-a';
                assert_screen 'addon-selection', 15;
            }
        }
        assert_screen 'addon-list', 5;
        send_key 'alt-n', 3;    # done
    }
    else {
        send_key 'alt-n', 3;    # done
    }

    if (check_screen("local-registration-servers", 10)) {
        send_key $cmd{ok};
    }
}

1;
# vim: set sw=4 et:
