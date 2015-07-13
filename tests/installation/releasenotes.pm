use base "opensusebasetest";    # use opensusebasetest to avoid fatal flag
use strict;
use testapi;

sub run(){
    my $self=shift;

    if (get_var("ADDONS")) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key "alt-l";   # open release notes window
            send_key 'alt-s';   # jump to first tab
        }
        else {
            assert_and_click 'release-notes-button';    # open release notes window
            assert_and_click 'release-notes-tab-sle';   # click on first SLES tab
        }
        assert_screen 'release-notes-sle';  # SLE release notes
        foreach $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-s';   # jump to first tab
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
        if (check_screen 'release-notes-tab') {
            record_soft_failure;    # https://bugzilla.suse.com/show_bug.cgi?id=935599
        }
    }

    send_key 'alt-o';   # exit release notes window
    if (check_screen 'release-notes-sle', 5) { #rbrown - quick workaround to unblock stagings when the OK button seemed to suddenly become Close
        record_soft_failure;
        send_key 'alt-c';
    }
    if (!get_var("UPGRADE")) {
        send_key 'alt-e';   # select timezone region as previously selected
    }
}

1;
