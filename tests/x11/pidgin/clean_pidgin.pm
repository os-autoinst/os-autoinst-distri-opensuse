# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Cleaning for testing pidgin
# Maintainer: Chingkai <qkzhu@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'clear_console';

sub remove_pkg {
    my @packages = qw(pidgin);
    x11_start_program('xterm');

    # Remove packages
    assert_script_sudo "rpm -e @packages";
    clear_console;
    type_string "rpm -qa @packages\n";
    assert_screen "pidgin-pkg-removed";    #make sure pkgs removed.
    type_string "exit\n";
}

sub run {
    remove_pkg;
}

1;
