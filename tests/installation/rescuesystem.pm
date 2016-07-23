# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils qw/ensure_shim_import/;

sub run {
    my $self = shift;

    ensure_shim_import;
    $self->select_bootmenu_option('inst-rescuesystem', 1);

    if (check_screen "keyboardmap-list", 100) {
        send_key "ret";
    }
    else {
        record_soft_failure;
    }

    # Login as root (no password)
    assert_screen "rescuesystem-login";
    type_string "root\n";

    # Clean the screen
    sleep 1;
    type_string "reset\n";
    assert_screen "rescuesystem-prompt";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
