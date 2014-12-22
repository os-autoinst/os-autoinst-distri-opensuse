use strict;
use base "y2logsstep";
use testapi;

sub run() {

    if ( check_screen('network-setup', 10)) { # won't appear for NET installs
        send_key $cmd{"next"};    # use network
        assert_screen 'dhcp-network';
        send_key 'alt-d'; # DHCP
        send_key "alt-o", 1;        # OK
    }
    my $repo = 0;
    $repo++ if get_var("DUD");

    assert_screen 'addon-selection', 15;

    if ( get_var("ADDONURL") ){

        if ( get_var("VIDEOMODE") && check_var("VIDEOMODE", "text") ) { $cmd{xnext} = "alt-x" }

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
        send_key 'alt-d';	# DVD
        send_key 'alt-n'; # next
        assert_screen 'dvd-selector', 3;

        if (check_var("ADDONS", "sdk")) {
            send_key "down"; # SR1
            send_key 'alt-o'; # continue
            assert_screen 'sdk-license', 10;
            send_key 'alt-y'; # yes, agree
            send_key 'alt-n';
            assert_screen 'addon-list';
            # TODO: continue with other addons
            send_key 'alt-n';
        }
    }
    #TODO Implment test that uses ISO_1 (SDK), _2 (HA), _3 (GEO) to add addons
}

1;
# vim: set sw=4 et:
