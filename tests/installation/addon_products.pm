use strict;
use base "y2logsstep";
use testapi;

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 10;
    while ( !check_screen( $tag, 1 ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

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
		
		foreach $a (split(/,/, get_var('ADDONS'))) {
			send_key 'alt-d';	# DVD
			send_key 'alt-n'; # next
            assert_screen 'dvd-selector', 3;
			key_round 'addon-dvd-list', 'tab';
			key_round "addon-dvd-$a", 'down';
			send_key 'alt-o';
			#Remove '&& ($a ne "sdk")' when boo912256 is fixed, remove '&& ($a ne "geo")' when boo912300 is fixed
            if (get_var("BETA") && ($a ne "sdk") && ($a ne "geo")) {
				assert_screen "addon-betawarning-$a", 10;
		    	send_key "ret";
				assert_screen "addon-license-beta", 10;
			}
			elsif ($a ne "geo") { # meant to be an else, remove if when boo912300 is fixed
				assert_screen "addon-license-$a", 10;
			} # remove line when boo912300 is fixed
			if ($a ne "geo"){ # remove line when boo912300 is fixed
			send_key 'alt-y'; # yes, agree
            send_key 'alt-n';
			} # remove line when boo912300 is fixed
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
