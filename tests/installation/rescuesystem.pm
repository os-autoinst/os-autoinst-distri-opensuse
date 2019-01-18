# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure rescue system can be booted into a shell prompt
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use bootloader_setup 'ensure_shim_import';

sub run {
    my $self = shift;

    # We can't see inst-sys on Xen PV, bootloader_svirt
    # does the job to get us into rescue mode.
    unless (check_var('VIRSH_VMM_TYPE', 'linux')) {
        ensure_shim_import;
        $self->select_bootmenu_more('inst-rescuesystem', 1);
    }

    assert_screen 'keyboardmap-list', 120;
    send_key "ret";

    # Login as root (no password)
    assert_screen "rescuesystem-login";
    type_string "root\n";

    # Clean the screen
    sleep 1;
    type_string "reset\n";
    assert_screen "rescuesystem-prompt";
}

sub test_flags {
    return {fatal => 1};
}

1;
