# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    send_key "alt-d";    # edit proposal settings
    sleep 2;
    if (get_var("ENCRYPT")) {
        send_key "alt-e";    # enable encrypted LVN-based proposal
    }
    else {
        send_key "alt-l";    # enable LVM-based proposal
    }
    assert_screen "inst-encrypt-password-prompt";
    type_password;
    send_key "tab";
    type_password;
    send_key "ret";
    if (get_var("ENCRYPT")) {
        assert_screen "partition-cryptlvm-summary";
    }
    else {
        assert_screen "partition-lvm-summary";
    }
    wait_still_screen(3, 7);
    send_key "alt-o";
}

1;
# vim: set sw=4 et:
