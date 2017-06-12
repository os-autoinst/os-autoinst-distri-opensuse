# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479556: Firefox: Gnome Shell Integration

# Summary: Case#1479556: Firefox: Gnome Shell Integration
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my ($self) = @_;
    $self->start_firefox;

    send_key "ctrl-w";
    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_and_click('firefox-plugins-tabicon');
    assert_screen('firefox-gnomeshell-default', 30);

    send_key "alt-d";
    sleep 1;
    type_string "extensions.gnome.org\n";
    assert_screen('firefox-gnomeshell-frontpage', 120);
    send_key "alt-a";
    assert_and_click "firefox-gnomeshell-allowremember";
    assert_and_click "firefox-gnomeshell-check_installed";
    # Maximize the window to ensure all relevant parts are in the viewable area
    send_key("super-up");
    assert_screen("firefox-gnomeshell-installed", 90);
    send_key "pgdn";
    assert_screen("firefox-gnomeshell-installed_02", 90);

    send_key "alt-d";
    type_string "extensions.gnome.org/extension/512/wikipedia-search-provider/\n";
    assert_screen([qw(firefox-reader-view firefox-gnomeshell-extension)], 90);
    if (match_has_tag 'firefox-reader-view') {
        assert_and_click('firefox-reader-close');
        assert_screen("firefox-gnomeshell-extension");
    }
    sleep 5;
    assert_and_click "firefox-gnomeshell-extension_install";
    assert_and_click "firefox-gnomeshell-extension_confirm";
    sleep 10;
    assert_screen("firefox-gnomeshell-extension_on", 60);

    # Exit
    $self->exit_firefox;

    sleep 2;
    x11_start_program("xterm");
    type_string "ls .local/share/gnome-shell/extensions/\n";
    sleep 2;
    assert_screen('firefox-gnomeshell-checkdir', 30);
    type_string "rm -rf .local/share/gnome-shell/extensions/*;exit\n";
}
1;
# vim: set sw=4 et:
