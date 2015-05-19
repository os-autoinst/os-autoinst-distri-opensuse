use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    if (get_var("UPGRADE") && get_var("ADDONS")) { # Netwrok setup
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

    if (get_var("UPGRADE") && get_var("ADDONS")) {
        foreach $a (split(/,/, get_var('ADDONS'))) {
            if ($a eq 'smt') {
                $self->key_round('used-repo-list', 'tab', 5);       # enable SMT repository
                $self->key_round('smt-repo-selected', 'down', 5);
                $self->key_round('used-smt-enabled', 'alt-t', 5);
                send_key $cmd{"next"}, 1;
                if (check_screen('network-not-configured', 5)) {
                    send_key 'ret', 1;          # Yes
                    send_key $cmd{"next"};      # use network
                    assert_screen 'dhcp-network';
                    send_key 'alt-d';           # DHCP
                    send_key "alt-o", 2;        # OK
                }
                record_soft_failure # https://bugzilla.suse.com/show_bug.cgi?id=928895
                assert_screen 'correct-media';  # Correct media request
                send_key "alt-o", 2;            # OK
            }
            else {
                send_key $cmd{"next"}, 1;
                send_key 'alt-d';	# DVD
                send_key $cmd{"xnext"}, 1;
                assert_screen 'dvd-selector', 3;
                $self->key_round('addon-dvd-list', 'tab', 10);
                $self->key_round("addon-dvd-$a", 'down', 10);
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
        }

        if (!check_var('ADDONS', 'smt')) {  # no add-on list for SMT
            assert_screen 'addon-list', 5;
            send_key $cmd{"next"}, 1;
        }
    }

    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
