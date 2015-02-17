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
    my $self = shift;
    
    if ( get_var("UPGRADE") && get_var("ADDONS") ) { # Netwrok setup
		if ( check_screen('network-setup', 10)) { # won't appear for NET installs
			send_key $cmd{"next"};    # use network
			assert_screen 'dhcp-network';
			send_key 'alt-d'; # DHCP
			send_key "alt-o", 2;        # OK
		}
    }

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1;

    assert_screen 'previously-used-repositories', 5;
    send_key $cmd{"next"}, 1;
    
    if ( get_var("UPGRADE") && get_var("ADDONS") ) {
		foreach $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-d';	# DVD
            send_key $cmd{"xnext"}, 1;
            assert_screen 'dvd-selector', 3;
            key_round 'addon-dvd-list', 'tab';
            key_round "addon-dvd-$a", 'down';
            send_key 'alt-o';
            if (get_var("BETA")) {
                assert_screen "addon-betawarning-$a", 10;
                send_key "ret";
                assert_screen "addon-license-beta", 10;
            }
            else {
                assert_screen "addon-license-$a", 10;
            }
            send_key 'alt-y'; # yes, agree
            send_key 'alt-n';
            assert_screen 'addon-list';
            if ((split(/,/, get_var('ADDONS')))[-1] ne $a) {
                send_key 'alt-a';
                assert_screen 'addon-selection', 15;
            }
        }
        
	assert_screen 'addon-list', 5;
    send_key $cmd{"next"}, 1;
    }

    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
