use base "y2logsstep";
use strict;
use testapi;

sub run() {

    if (!check_screen('release-notes-button', 5)) {    # workaround missing release notes
        record_soft_failure;
        return;
    }
    my @addons = split(/,/, get_var('ADDONS', ''));
    if (check_var('SCC_REGISTER', 'installation')) {
        push @addons, split(/,/, get_var('SCC_ADDONS', ''));
    }
    send_key "alt-l", 2;                               # open release notes window
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'tab';                                # select tab area
    }
    if (@addons) {
        for $a (@addons) {
            send_key_until_needlematch("release-notes-$a", 'right');
            send_key 'left';                           # move back to first tab
            send_key 'left';
            send_key 'left';
            send_key 'left';
        }
        send_key_until_needlematch("release-notes-sle", 'right');
    }
    else {
        assert_screen 'release-notes-sle';             # SLE release notes
    }
    # exit release notes window
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-o';
    }
    else {
        send_key 'alt-c';
    }
    if (!get_var("UPGRADE")) {
        send_key 'alt-e';                              # select timezone region as previously selected
    }
}

1;
# vim: sw=4 et
