use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'release-notes', 100; # suseconfig run
    
    if (get_var("ADDONS")) {
        foreach $a (split(/,/, get_var('ADDONS'))) {
            assert_and_click "release-notes-tab-$a";
            assert_screen "release-notes-$a";
        }
    }

    send_key $cmd{'next'};
}

1;
