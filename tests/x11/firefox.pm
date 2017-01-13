# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Very basic firefox test opening html5test
# Maintainer: Stephan Kulow <coolo@suse.com>

package firefox;
use base "x11test";
use strict;
use testapi;

sub start_firefox() {
    x11_start_program("firefox https://html5test.com/index.html", 6, {valid => 1});
    # makes firefox as default browser
    assert_screen [qw(firefox_default_browser firefox_readerview_window firefox-html5test)], 120;
    if (check_screen('firefox_default_browser', 0)) {
        assert_screen_change {
            assert_and_click 'firefox_default_browser_yes';
        };
    }
    assert_screen [qw(firefox_readerview_window firefox-html5test)];
    # workaround for reader view , it grabed the focus than mainwindow
    if (check_screen('firefox_readerview_window', 0)) {
        assert_screen_change {
            assert_and_click 'firefox_readerview_window';
        };
    }
    assert_screen 'firefox-html5test';
}

sub run() {
    my $self = shift;
    mouse_hide(1);
    $self->start_firefox();
    send_key "alt-h";
    assert_screen 'firefox-help-menu';
    send_key "a";
    assert_screen 'test-firefox-3';

    # close About
    send_key "alt-f4";
    assert_screen 'firefox-html5test';

    send_key "alt-f4";
    assert_screen [qw(firefox-save-and-quit generic-desktop)];
    if (match_has_tag 'firefox-save-and-quit') {
        # confirm "save&quit"
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:
