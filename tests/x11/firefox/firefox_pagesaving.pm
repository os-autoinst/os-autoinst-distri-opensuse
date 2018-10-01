# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436102: Firefox: Page Saving
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    $self->firefox_open_url('http://www.mozilla.org/en-US');

    assert_screen('firefox-pagesaving-load', 90);
    send_key "ctrl-s";
    assert_screen 'firefox-pagesaving-saveas';
    send_key "alt-s";

    # Exit
    $self->exit_firefox;

    x11_start_program('xterm');
    send_key "ctrl-l";
    wait_still_screen 3;
    type_string "ls Downloads/\n";
    assert_screen 'firefox-pagesaving-downloads';
    assert_script_run 'rm -rf Downloads/*';
    send_key "ctrl-d";
}
1;
