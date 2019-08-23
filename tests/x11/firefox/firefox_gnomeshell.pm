# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479556: Firefox: Gnome Shell Integration

# Summary: Case#1479556: Firefox: Gnome Shell Integration
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open firefox addon manager
# - Check if gnomeshell plugin exists
# - Open url "extensions.gnome.org"
# - Allow firefox to run gnomeshell extension
# - Open url "extensions.gnome.org/extension/512/wikipedia-search-provider/" and
# check
# - Install extension
# - Cleanup installed extension
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    send_key "ctrl-shift-a";
    assert_and_click('firefox-addons-plugins');
    assert_screen [qw(firefox-gnomeshell-default firefox-plugins-missing)], 60;
    if (match_has_tag('firefox-plugins-missing')) {
        record_info 'Dropped support for NPAPI plugins since Firefox 52+', 'bsc#1077707 - GNOME Shell Integration and other two plugins are not installed by default';
        $self->exit_firefox;
        return;
    }

    $self->firefox_open_url('extensions.gnome.org');
    assert_screen('firefox-gnomeshell-frontpage');
    send_key "alt-a";
    assert_and_click "firefox-gnomeshell-allowremember";
    assert_and_click "firefox-gnomeshell-check_installed";
    # Maximize the window to ensure all relevant parts are in the viewable area
    send_key("super-up");
    assert_screen("firefox-gnomeshell-installed", 90);
    send_key "pgdn";
    assert_screen("firefox-gnomeshell-installed_02", 90);

    $self->firefox_open_url('extensions.gnome.org/extension/512/wikipedia-search-provider/');
    assert_screen "firefox-gnomeshell-extension";
    assert_and_click "firefox-gnomeshell-extension_install";
    assert_and_click "firefox-gnomeshell-extension_confirm";
    assert_screen("firefox-gnomeshell-extension_on", 60);

    # Exit
    $self->exit_firefox;

    x11_start_program('xterm');
    type_string "ls .local/share/gnome-shell/extensions/\n";
    assert_screen('firefox-gnomeshell-checkdir', 30);
    type_string "rm -rf .local/share/gnome-shell/extensions/*;exit\n";
}
1;
