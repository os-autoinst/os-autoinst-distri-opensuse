# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice
# Summary: LibreOffice: Favorite Documents link in Computer menu
# - Open desktop main menu
# - Open favorite documents list
# - Click libreoffice
# - Quit libreoffice
# Maintainer: Zhaocong Jia <zcjia@suse.com>
# Tags: tc#1503906

use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    # start destop application memu
    wait_still_screen;
    send_key "super";
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
