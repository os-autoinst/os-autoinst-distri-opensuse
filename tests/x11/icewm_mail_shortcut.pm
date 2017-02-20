# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test mail shortcut on icewm panel
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    return unless check_var('DESKTOP', 'minimalx');
    select_console 'x11';
    assert_and_click 'icewm_systray_mail_shortcut';
    assert_screen 'minimalx_mail_client';
}

1;

# vim: set sw=4 et:
