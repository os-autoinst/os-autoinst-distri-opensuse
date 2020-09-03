# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
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
    send_key('alt');
    assert_screen('firefox-top-bar-highlighted');
    send_key('h');
    assert_screen('firefox-help-menu');
    send_key_until_needlematch('test-firefox-3', 'a', 9, 6);

    # close About
    send_key "alt-f4";
    assert_screen 'firefox-html-test';

    send_key "alt-f4";
    assert_screen([qw(firefox-save-and-quit generic-desktop not-responding)], timeout => 90);
    if (match_has_tag 'not-responding') {
        record_soft_failure "firefox is not responding, see boo#1174857";
        # confirm "save&quit"
        send_key_until_needlematch('generic-desktop', 'ret', 9, 6);
    }
    elsif (match_has_tag 'firefox-save-and-quit') {
        # confirm "save&quit"
        send_key_until_needlematch('generic-desktop', 'ret', 9, 6);
    }
}

1;
