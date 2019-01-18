# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: LibreOffice: Favorite Documents link in Computer menu
# Maintainer: dehai <dhkong@suse.com>
# Tags: tc#1503906

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub run {
    # start destop application memu
    wait_still_screen;
    send_key "alt-f1";
    assert_screen('test-desktop_mainmenu-1');

    # find the favorites button
    if (is_sle '<15') {
        assert_and_click('application-menu-favorites');
        assert_screen('menu-favorites-libreoffice');
    }

    # find the LibreOffice
    assert_and_click('favorites-list-libreoffice');
    assert_screen('welcome-to-libreoffice', 90);

    # exit LibreOffice
    send_key "ctrl-q";
}
1;
