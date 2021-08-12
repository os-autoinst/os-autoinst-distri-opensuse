# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: inkscape
# Summary: Test inkscape can be installed and started
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed('inkscape', timeout => 300);
    x11_start_program('inkscape', target_match => [qw(inkscape inkscape-welcome-save)]);
    if (match_has_tag('inkscape-welcome-save')) {
        # Inkscape 1.1+ welcome screen
        click_lastmatch;
        assert_and_click('inkscape-welcome-thanks');
        assert_and_click('inkscape-welcome-new_document');
        assert_screen('inkscape');
    }
    send_key "alt-f4";    # Exit
}

1;
