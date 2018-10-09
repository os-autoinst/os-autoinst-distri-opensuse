# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436084: Firefox: Open IE MHTML Files
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    # Fetch mht file to shm
    x11_start_program("wget " . autoinst_url . "/data/x11/ie10.mht -O /dev/shm/ie10.mht", valid => 0);

    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 90);
    assert_and_click "firefox-extensions";
    assert_and_click "firefox-searchall-addon";
    type_string "unmht\n";
    assert_and_click('firefox-mhtml-unmht');
    for my $i (1 .. 2) { send_key "tab"; }
    send_key "spc";
    # mhtml is not running on SLE15+
    assert_and_click('unmht_restart_now');
    wait_still_screen 3;
    assert_and_click('firefox-my-addons');
    # refresh addon list to show newly installed addons
    send_key 'f5';
    assert_screen('firefox-mhtml-unmht_installed', 90);

    wait_screen_change { send_key "ctrl-w" };

    $self->firefox_open_url('file:///dev/shm/ie10.mht');
    assert_screen('firefox-mhtml-loadpage');

    # Exit and Clear
    $self->exit_firefox;
    wait_still_screen 3;
    x11_start_program('rm /dev/shm/ie10.mht', valid => 0);
}
1;
