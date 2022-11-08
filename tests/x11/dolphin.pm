# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dolphin
# Summary: Start dolphin and do some file operations
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'assert_screen_with_soft_timeout';

sub run {
    x11_start_program 'dolphin';

    # Go to ~/Documents
    assert_and_click 'dolphin_icon_documents';
    assert_screen_with_soft_timeout('dolphin_documents_empty', timeout => 90, soft_timeout => 30, bugref => 'boo#1112021');

    # Create a new folder
    send_key 'f10';
    assert_screen 'dolphin_new_folder_dialog';
    type_string 'stuff';
    assert_screen 'dolphin_new_folder';
    send_key 'ret';
    # Check new folder is created
    assert_screen 'dolphin_stuff_folder';
    # Enter the new folder
    send_key 'ret';

    # Context menu: "Create new" -> "Text file"
    assert_and_click('dolphin_stuff_empty', button => 'right');
    my $create_new = assert_screen 'dolphin_create_new';

    my $lastarea = $create_new->{area}->[-1];
    my $x = int($lastarea->{x} + $lastarea->{w} / 2);
    my $y = int($lastarea->{y} + $lastarea->{h} / 2);

    # Workaround: In 42.3 clicking without moving doesn't open the submenu
    mouse_set($x - 5, $y);
    mouse_click();
    mouse_set($x, $y);

    assert_and_click 'dolphin_create_new_text_file';
    mouse_hide();
    assert_screen 'dolphin_new_text_file_dialog';
    type_string 'empty';
    assert_screen 'dolphin_new_text_file';
    send_key 'ret';
    assert_screen 'dolphin_stuff_full';

    # Go back up to ~/Documents
    assert_and_click 'dolphin_navbar_documents';
    # Add "stuff" to Places
    assert_and_click('dolphin_icon_stuff', button => 'right');
    assert_and_click 'dolphin_add_places';

    # Verify that it's visible in the file picker
    x11_start_program('kdialog --getopenfilename', valid => 0);
    assert_screen 'kdialog_places_stuff';
    send_key 'alt-f4';

    # Remove the directory forcibly
    assert_screen 'dolphin_icon_stuff';
    send_key 'shift-delete';
    # Only before 22.11 the delete button was focused by default,
    # click it directly on newer versions.
    assert_screen([qw(dolphin_force_remove dolphin_force_remove_button)]);
    if (match_has_tag('dolphin_force_remove_button')) {
        click_lastmatch;
    } else {
        send_key 'ret';
    }

    # Remove the places entry again
    assert_and_click('dolphin_places_stuff', button => 'right');
    assert_and_click 'dolphin_places_remove';

    send_key 'alt-f4';
}

1;
