use base "opensusebasetest";    # use opensusebasetest to avoid fatal flag
use strict;
use testapi;

sub run(){
    my $self=shift;

    if (check_var('VIDEOMODE', 'text')) {
        send_key "alt-l";   # open release notes window
        send_key 'alt-s';   # jump to first tab
        assert_screen 'release-notes-tab-sle';
    }
    else {
        assert_and_click 'release-notes-button';    # open release notes window
        assert_and_click 'release-notes-tab-sle';   # click on first SLES tab
    }
    if (get_var("ADDONS")) {
        foreach $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-s';   # jump to first tab
            send_key_until_needlematch("release-notes-tab-$a", 'right');
        }
    }
    send_key 'alt-o';   # exit release notes window
    send_key 'alt-e';   # select region as previous selected
}

1;
