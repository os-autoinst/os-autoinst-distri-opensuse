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
    send_key_until_needlematch('firefox-help-menu', 'alt-h', 5, 6);
    send_key_until_needlematch('test-firefox-3',    'a',     5, 6);

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
