# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1503906 - LibreOffice: Favorite Documents link in Computer menu.

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # start destop application memu
    wait_still_screen;
    send_key "alt-f1";
    assert_screen('test-desktop_mainmenu-1', 30);
    assert_and_click 'application-menu-list';

    # find the favorites button
    send_key_until_needlematch 'application-menu-favorites', 'down';
    assert_screen('menu-favorites-libreoffice', 30);

    # find the LibreOffice
    send_key "right";
    send_key_until_needlematch 'favorites-list-libreoffice', 'up';
    send_key "ret";
    assert_screen('welcome-to-libreoffice', 30);

    # exit LibreOffice
    send_key "ctrl-q";
}
1;
# vim: set sw=4 et:
