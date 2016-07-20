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

sub run {
    my $self = shift;

    assert_screen([qw/inst-bootmenu bootloader-shim-import-prompt/], 15);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
    }
    $self->select_bootmenu_option('inst-onmemtest', 1);
    assert_screen "pass-complete", 700;
    send_key "esc";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
