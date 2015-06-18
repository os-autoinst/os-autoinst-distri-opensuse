use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my ($self) = @_;

    if ( check_screen('network-setup', 10)) { # won't appear for NET installs
        send_key $cmd{"next"};    # use network
        assert_screen 'dhcp-network';
        send_key 'alt-d', 2;    # DHCP
        send_key 'alt-o', 2;    # OK
    }
    my $repo = 0;
    $repo++ if get_var("DUD");

    assert_screen 'addon-selection', 15;

    if ( get_var("ADDONURL") ){

        foreach my $url ( split( /\+/, get_var("ADDONURL") ) ) {
            if ( $repo++ ) { send_key "alt-a", 1; }    # Add another
            send_key $cmd{"xnext"}, 1;                 # Specify URL (default)
            type_string $url;
            send_key $cmd{"next"}, 1;
            if ( get_var("ADDONURL") !~ m{/update/} ) {    # update is already trusted, so would trigger "delete"
                send_key "alt-i";
                send_key "alt-t", 1;                     # confirm import (trust) key
            }
        }
        assert_screen 'test-addon_product-1', 3;
        send_key $cmd{"next"}, 1;                        # done
    }

    if ( get_var("ADDONS")) {

        foreach $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-d';	# DVD
            send_key $cmd{"xnext"}, 1;
            assert_screen 'dvd-selector', 3;
            send_key_until_needlematch 'addon-dvd-list', 'tab';
            send_key_until_needlematch "addon-dvd-$a", 'down';
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
            send_key 'alt-y'; # yes, agree
            sleep 2;
            send_key 'alt-n';
            assert_screen 'addon-list';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $a) {
                send_key 'alt-a';
                assert_screen 'addon-selection', 15;
            }

        }

        send_key 'alt-n';

    }
}

1;
# vim: set sw=4 et:
