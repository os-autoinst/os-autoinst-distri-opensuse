# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test firefox HTTP headers (Case#1436066)
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"", valid => 0);
    x11_start_program('firefox');
    $self->firefox_check_popups;
    assert_screen('firefox-launch', 90);

    send_key "esc";
    send_key "ctrl-shift-q";
    assert_screen 'firefox-headers-inspector';
    $self->firefox_open_url('www.gnu.org');
    assert_screen('firefox-headers-website', 90);

    send_key "down";
    assert_screen('firefox-headers-first_item', 50);

    send_key "shift-f10";
    #"Edit and Resend"
    send_key "e";

    assert_screen('firefox-headers-user_agent', 50);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 30)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
