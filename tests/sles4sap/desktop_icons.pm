# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SLES for SAP Applications default desktop icons check
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use strict;

sub run {
    my ($self) = @_;

    select_console 'x11';
    # Check for SLES4SAP Desktop icons
    if (check_screen 'sles4sap-desktop') {
        assert_and_dclick 'sles4sap-desktop-cheatsheet';
        assert_screen 'sles4sap-cheatsheet';
        send_key 'alt-f4';
    }
    else {
        # There was no match for the desktop icons needle
        # Verify that there's at least a generic desktop and soft fail
        assert_screen 'generic-desktop';
        record_soft_failure 'bsc#1072646';
    }
}

1;
# vim: set sw=4 et:
