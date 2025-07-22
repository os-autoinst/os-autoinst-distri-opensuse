# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: write instsys and initrd package lists to log
#    this allows to better check and compare versions
#    to find what might have introduced a bug
#    or if the new version with a proposed fix is already included.
# Maintainer: QE LSG <qa-team@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    # the waiting might take long in case of online update repos being
    # initialized before that screen
    my $waiting_point = get_var('NEW_DESKTOP_SELECTION') ? 'role' : 'package';
    assert_screen "before-$waiting_point-selection", 300;
    select_console 'install-shell';
    script_run "(cat /.timestamp ; echo /.packages.initrd: ; cat /.packages.initrd) > /dev/$serialdev";
    script_run "(echo /.packages.root: ; cat /.packages.root) > /dev/$serialdev";
    save_screenshot;
    select_console 'installation';
}

1;
