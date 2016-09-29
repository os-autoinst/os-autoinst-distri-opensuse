# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add bootting mediacheck from yaboot
#    Signed-off-by: Dinar Valeev <dvaleev@suse.com>
# G-Maintainer: Dinar Valeev <dvaleev@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "bootloader-ofw-yaboot", 15;

    type_string "install mediacheck=1";
    send_key "ret";

    # the timeout is insane - but SLE11 DVDs take almost forever
    assert_screen "mediacheck-ok", 1600;
    send_key "ret";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
