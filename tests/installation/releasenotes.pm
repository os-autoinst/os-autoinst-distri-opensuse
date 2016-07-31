# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub run() {

    if (!check_screen('release-notes-button', 5)) {
        record_soft_failure 'workaround missing release notes';
        return;
    }
    my $addons = get_var('ADDONS', get_var('ADDONURL', ''));
    my @addons = split(/,/, $addons);
    if (check_var('SCC_REGISTER', 'installation')) {
        push @addons, split(/,/, get_var('SCC_ADDONS', ''));
    }
    if (get_var("UPGRADE")) {
        send_key "alt-e";    # open release notes window
    }
    else {
        if (check_var('VIDEOMODE', 'text')) {
            send_key "alt-l";    # open release notes window
        }
        else {
            assert_and_click('release-notes-button');
        }
    }
    wait_still_screen(2);
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'tab';          # select tab area
    }
    if (@addons) {
        for my $a (@addons) {
            next if ($a eq 'we');    # https://bugzilla.suse.com/show_bug.cgi?id=931003#c17
            send_key_until_needlematch("release-notes-$a", 'right', 4, 60);
            send_key 'left';         # move back to first tab
            send_key 'left';
            send_key 'left';
            send_key 'left';
        }
        send_key_until_needlematch("release-notes-sle", 'right');
    }
    else {
        assert_screen 'release-notes-sle';    # SLE release notes
    }
    # exit release notes window
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-o'; };
    }
    else {
        assert_screen([qw/release-notes-sle-ok-button release-notes-sle-close-button/]);
        if (match_has_tag('release-notes-sle-ok-button')) {
            wait_screen_change { send_key 'alt-o' };
        }
        else {
            wait_screen_change { send_key 'alt-c'; };
        }
    }
    if (!get_var("UPGRADE")) {
        send_key 'alt-e';    # select timezone region as previously selected
    }
}

1;
# vim: sw=4 et
