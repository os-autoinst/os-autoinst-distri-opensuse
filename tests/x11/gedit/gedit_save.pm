# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gedit wget
# Summary: Gedit: save file
# - Download test text file from datadir
# - Launch gedit and open text test file
# - Delete one line
# - Select a line and copy
# - Paste
# - Go to end of document and type: "This file is opened, edited and saved by openQA!"
# - Save and quit gedit
# - Launch gedit, open text test file and check
# - Exit gedit, erase test file
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>
# Tags: tc#1436121

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    # download test text file from x11 data directory
    x11_start_program("wget " . autoinst_url . "/data/x11/test.txt", valid => 0);

    # open test text file locally
    x11_start_program('gedit ' . 'test.txt', target_match => 'gedit-file-opened');

    # delete one line
    send_key "ctrl-d";
    send_key "ret";

    # copy one line and past it
    mouse_set(500, 350);
    mouse_tclick('left', 0.10);    # triple click to select a line
    sleep 1;

    send_key "ctrl-c";    # copy
    send_key "right";
    send_key "ret";
    send_key "ctrl-v";    # paste in next line

    # edit some words
    send_key "ctrl-end";    # go to the end of document
    send_key "ret";
    type_string "This file is opened, edited and saved by openQA!";
    sleep 1;

    # save and quit
    wait_screen_change { send_key "ctrl-s"; };
    send_key "ctrl-q";
    wait_still_screen 3;

    # open saved file to validate
    x11_start_program('gedit ' . 'test.txt', target_match => 'gedit-saved-file');
    wait_screen_change { send_key "ctrl-q"; };

    # clean up saved file
    x11_start_program("rm " . "test.txt", valid => 0);
}

1;
