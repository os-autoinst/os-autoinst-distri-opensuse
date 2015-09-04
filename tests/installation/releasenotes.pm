use base "opensusebasetest";    # use opensusebasetest to avoid fatal flag
use strict;
use testapi;

sub run(){
    my $self=shift;

    if (get_var("ADDONS") || get_var("SCC_ADDONS")) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key "alt-l";   # open release notes window
            send_key 'alt-s';   # select SLES SP1 release notes
            assert_screen 'release-notes-sle';  # SLE release notes
        }
        else {
            assert_and_click 'release-notes-button';    # open release notes window
            assert_and_click 'release-notes-tab';       # click on first SLES tab
            send_key_until_needlematch("release-notes-sle", 'right'); # tab not visible with three add-ons
        }
        for $a (split(/,/, get_var('ADDONS')), split(/,/, get_var('SCC_ADDONS'))) {
            send_key 'left';    # move to first tab
            send_key 'left';
            send_key 'left';
            send_key 'left';
            send_key_until_needlematch("release-notes-tab-$a", 'right');
        }
    }
    else {
        if (check_var('VIDEOMODE', 'text')) {
            send_key "alt-l";   # open release notes window
        }
        else {
            assert_and_click 'release-notes-button';    # open release notes window
        }
        assert_screen 'release-notes-sle';  # SLE release notes
    }
    # exit release notes window
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-o';
    }
    else {
        send_key 'alt-c';
    }
    if (!get_var("UPGRADE")) {
        send_key 'alt-e';   # select timezone region as previously selected
    }
}

1;
