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

    send_key "alt-d";
    sleep 2;

    send_key "alt-l", 1;    # enable LVM-based proposal
    if (get_var("ENCRYPT")) {
        send_key "alt-y", 1;
        assert_screen "inst-encrypt-password-prompt";
        type_password;
        send_key "tab";
        type_password;
        send_key "ret",                             1;
        assert_screen "partition-cryptlvm-summary", 3;
    }
    else {
        assert_screen "partition-lvm-summary", 3;
    }
    wait_idle 5;
    send_key "alt-o";
}

1;
# vim: set sw=4 et:
