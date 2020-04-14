# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Very basic firefox test opening an html-test
# - Start firefox with url "https://html5test.opensuse.org"
# - Open about window and check
# - Exit firefox
# Maintainer: Stephan Kulow <coolo@suse.com>

package firefox;
use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils 'is_tumbleweed';

sub run() {
    my ($self) = shift;

    $self->start_firefox;
    wait_still_screen;
    # we have poor performance on LIVETEST, use assert_and_click here
    if (is_tumbleweed && get_var("LIVETEST")) {
        send_key_until_needlematch('firefox-help-menu', 'alt', 4, 10);    # show menu bar
        assert_and_click 'firefox-help-menu';
        assert_and_click 'firefox-help-about';
    }
    else {
        send_key "alt-h";
        assert_screen 'firefox-help-menu';
        send_key "a";
    }
    assert_screen 'test-firefox-3';

    # close About
    send_key "alt-f4";
    assert_screen 'firefox-html-test';

    send_key "alt-f4";
    assert_screen [qw(firefox-save-and-quit generic-desktop)];
    if (match_has_tag 'firefox-save-and-quit') {
        # confirm "save&quit"
        send_key "ret";
    }
}

1;
