# LibreOffice tests
#
# Copyright 2016-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice-writer
# Summary: LibreOffice: Verify Main Menu Recent Documents get populated
#   with files accessed and modified using LibreOffice (Case 1503783)
# - Launch oowriter
# - Write "Hello World!" and save the file as "hello.odt"
# - Close libreoffice
# - Relaunch oowriter and check Recent documents
# - Clear recent documents list
# - Quit libreoffice
# - Cleanup
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use Mojo::Base 'x11test';
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    my ($self) = shift;

    # Edit file hello.odt using oowriter
    $self->libreoffice_start_program('oowriter');
    # clicking the writing area to make sure the cursor addressed there
    assert_and_click('ooffice-writing-area', timeout => 10);
    wait_still_screen;
    type_string "Hello World!";
    assert_screen 'test-ooffice-2';
    send_key "alt-f4";
    assert_screen "ooffice-save-prompt";
    send_key "alt-s";    # Save the file
    assert_screen 'ooffice-save-prompt-2';
    type_string "hello";
    send_key "ret";

    # Check Recent Documents
    wait_still_screen;
    $self->libreoffice_start_program('oowriter');

    send_key "alt-f";
    # The menu may disappear due to boo#1156745, so we wait here
    wait_still_screen(2);
    assert_screen [qw(oowriter-menus-file oowriter)];
    if (match_has_tag 'oowriter') {
        record_soft_failure('workaround for boo#1156745');
        assert_and_click('ooffice-writing-file', timeout => 10);
        assert_screen 'oowriter-menus-file';
    }

    send_key 'down', wait_screen_change => 1;
    send_key 'u';

    assert_screen 'oowriter-menus-file-recentDocuments';
    send_key_until_needlematch("libreoffice-clear-list", "down");
    send_key "ret", wait_screen_change => 1;
    assert_screen [qw(test-ooffice-1 oowriter clear-recent-documents)];

    if (match_has_tag('clear-recent-documents')) {
        send_key "alt-f4", wait_screen_change => 1;
    }

    # Quit oowriter
    assert_and_click('ooffice-writing-area', timeout => 10);
    send_key "ctrl-q";

    assert_screen 'generic-desktop';

    # Clean test file
    x11_start_program("rm /home/$username/Documents/hello.odt", valid => 0);
}

1;
