# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: inkscape
# Summary: Test inkscape can be installed and started
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use testapi;

sub run {
    select_console 'x11';
    ensure_installed('inkscape', timeout => 300);
    x11_start_program('inkscape', target_match => [qw(inkscape inkscape-welcome-save inkscape-welcome-boo1241066)]);
    if (match_has_tag('inkscape-welcome-save')) {
        # Inkscape 1.1+ welcome screen
        click_lastmatch;
        assert_and_click('inkscape-welcome-thanks');
        assert_and_click('inkscape-welcome-new_document');
        assert_screen('inkscape');
    } elsif (match_has_tag('inkscape-welcome-boo1241066')) {
        click_lastmatch;
    }
    send_key "alt-f4";    # Exit
}

1;
