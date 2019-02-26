# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479188: Firefox: Add-ons - Plugins

# Summary: Case#1479188: Firefox: Add-ons - Plugins
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_and_click('firefox-addons-plugins');
    assert_screen [qw(firefox-plugins-overview_01 firefox-plugins-missing)], 60;
    if (match_has_tag('firefox-plugins-missing')) {
        record_info 'Dropped support for NPAPI plugins since Firefox 52+', 'bsc#1077707 - GNOME Shell Integration and other two plugins are not installed by default';
        $self->exit_firefox;
        return;
    }

    for my $i (1 .. 2) { send_key "tab"; }
    send_key "pgdn";
    assert_screen('firefox-plugins-overview_02', 60);
    assert_and_click('firefox-plugins-tools');
    assert_and_click('firefox-plugins-check_update');
    assert_screen('firefox-plugins-updates', 60);

    $self->exit_firefox;
}
1;
