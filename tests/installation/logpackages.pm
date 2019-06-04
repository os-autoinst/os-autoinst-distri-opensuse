# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: write instsys and initrd package lists to log
#    this allows to better check and compare versions
#    to find what might have introduced a bug
#    or if the new version with a proposed fix is already included.
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    # the waiting might take long in case of online update repos being
    # initialized before that screen
    if (get_var('NEW_DESKTOP_SELECTION')) {
        assert_screen 'before-role-selection', 300;
    }
    else {
        assert_screen 'before-package-selection', 300;
    }
    select_console 'install-shell';
    script_run "(cat /.timestamp ; echo /.packages.initrd: ; cat /.packages.initrd) > /dev/$serialdev";
    script_run "(echo /.packages.root: ; cat /.packages.root) > /dev/$serialdev";
    save_screenshot;
    select_console 'installation';
}

1;
