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
use version_utils 'is_sle';
use strict;
use warnings;

sub run {
    my ($self) = @_;

    select_console 'x11';
    # Check for SLES4SAP Desktop icons
    if (check_screen 'sles4sap-desktop', 30) {
        assert_and_dclick 'sles4sap-desktop-cheatsheet';
        assert_screen 'sles4sap-cheatsheet', 90;
        send_key 'alt-f4';
    }
    else {
        # There was no match for the desktop icons needle
        # Verify that there is at least a generic desktop and
        # fail unless we're in SLE-15 where there are no icons
        assert_screen 'generic-desktop';
        record_soft_failure 'bsc#1072646' unless is_sle('15+');
    }
}

1;
