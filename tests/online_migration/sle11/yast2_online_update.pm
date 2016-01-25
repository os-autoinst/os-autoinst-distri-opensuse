# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

sub packagekitd() {
    #packagekitd locked sometimes appear
    while (check_screen([qw/packagekitd refresh-repos/], 15)) {
        last if match_has_tag("refresh-repos");
        send_key "alt-y";
    }
}

sub run() {
    my $self = shift;

    # online update take very long time, so make sure that
    # the vm image has been updated at least once
    type_string "yast2 online_update\n";
    packagekitd();
    assert_screen 'online-update-overview', 500;
    send_key "alt-a";

    assert_screen 'online-update-started', 20;

    # restart online update may appear
    my @tags    = qw/online-update-restart online-update-finish/;
    my $timeout = 1000;
    while (check_screen(\@tags, $timeout)) {
        if (match_has_tag("online-update-restart")) {
            send_key "alt-o";
            assert_screen 'online-update-overview', 50;
            send_key "alt-a";
            next;
        }
        last if match_has_tag("online-update-finish");
    }
}

1;
# vim: set sw=4 et:
