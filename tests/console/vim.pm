# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test vim editor display including syntax highlighting
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use testapi;

sub run() {
    assert_script_run 'rpm -qi vim';
    type_string "vim /etc/passwd\n";
    assert_screen 'vim-showing-passwd';
    wait_screen_change { type_string ":q!\n" };
}

1;
