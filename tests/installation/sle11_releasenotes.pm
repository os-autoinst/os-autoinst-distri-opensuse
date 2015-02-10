use base "y2logsstep";
use strict;
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

sub run(){
    my $self=shift;

    assert_screen 'release-notes', 100; # suseconfig run
    
    if (get_var("ADDONS")) {
        if (check_screen 'release-notes-tab') {
            foreach $a (split(/,/, get_var('ADDONS'))) {
                assert_and_click "release-notes-tab-$a";
                assert_screen "release-notes-$a";
            }
            assert_and_click "release-notes-tab-sle";
            assert_screen "release-notes-sle";
        }
        else {
            foreach $a (split(/,/, get_var('ADDONS'))) {
                send_key 'alt-p';
                send_key ' ';
                send_key 'pgup';
                key_round "release-notes-list-$a", 'down';
                send_key 'ret';
                assert_screen "release-notes-$a";
            }
            send_key 'alt-p';
            send_key ' ';
            send_key 'pgup';
            key_round "release-notes-list-sle", 'down';
            send_key 'ret';
            assert_screen "release-notes-sle";
        }
    }
    else {
        assert_screen "release-notes-sle";
    }

    send_key $cmd{'next'};
}

1;
