# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: MozillaFirefox
# Summary: Case#1479221: Firefox: HTML5 Video
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open "youtube.com/html5" and check result
# - Open "youtube.com/watch?v=Z4j5rJQMdOU" and check result
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    $self->firefox_open_url('youtube.com/watch?v=Z4j5rJQMdOU');
    while (check_screen([qw(firefox-youtube-signin firefox-accept-youtube-cookies)], 15)) {
        if (match_has_tag('firefox-accept-youtube-cookies')) {
            # get to the accept button with tab and space
            wait_still_screen(2);
            send_key_until_needlematch('firefox-accept-youtube-cookies-agree', 'tab', 7, 1);
            assert_and_click('firefox-accept-youtube-cookies-agree');
            wait_still_screen(2);
            next;
        }
        elsif (match_has_tag('firefox-youtube-signin')) {
            assert_and_click('firefox-youtube-signin');
            wait_still_screen(2);
            next;
        }
        last;
    }
    send_key_until_needlematch('firefox-testvideo', 'spc', 15, 5);
    $self->exit_firefox;
}
1;
