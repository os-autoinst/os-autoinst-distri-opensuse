# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479188: Firefox: Add-ons - Plugins

# Summary: Case#1479188: Firefox: Add-ons - Plugins
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my ($self) = @_;
    $self->start_firefox;

    send_key "ctrl-shift-a";
    assert_and_click('firefox-addons-plugins');
    assert_screen('firefox-plugins-overview_01', 60);

    for my $i (1 .. 2) { send_key "tab"; }
    send_key "pgdn";
    assert_screen('firefox-plugins-overview_02', 60);

    assert_and_click('firefox-plugins-check_update');
    assert_screen('firefox-plugins-update_page', 60);

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
