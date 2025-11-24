# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1436102: Firefox: Page Saving
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open "http://www.mozilla.org/en-US"
# - Download the opened page (save as)
# - Exit firefox
# - Open xterm
# - Run "ls Downloads/|grep -Ei "(mozilla)|(\.html|_files)"
# - Delete downloaded page
# - Exit xterm
# Maintainer: wnereiz <wnereiz@gmail.com>

use base "x11test";
use testapi;
use x11utils 'default_gui_terminal';

sub run {
    my ($self) = @_;

    # ensure a clean Downloads directory
    x11_start_program(default_gui_terminal());
    wait_still_screen 3;
    assert_script_run 'rm -rf ~/Downloads/*';
    send_key "ctrl-d";

    $self->start_firefox_with_profile;
    $self->firefox_open_url('http://www.mozilla.org/en-US', assert_loaded_url => 'firefox-pagesaving-load');
    send_key "ctrl-s";
    assert_screen 'firefox-pagesaving-saveas';
    wait_still_screen 3;
    # on sle15 just one alt-s does not work
    send_key_until_needlematch 'firefox-downloading-saving_dialog', 'alt-s', 4, 3;

    # Exit
    $self->exit_firefox;

    x11_start_program(default_gui_terminal());
    send_key "ctrl-l";
    wait_still_screen 3;
    # look for file with "mozilla or Internet for people, not profit"
    # in its name
    assert_script_run 'ls Downloads/|grep -Ei "(mozilla)|(Internet for people, not profit)"';
    assert_script_run 'rm -rf Downloads/*';
    send_key "ctrl-d";
}
1;
