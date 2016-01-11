# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# case 1436174-test function search all notes

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 5;
    send_key_until_needlematch 'gnote-start-here-matched', 'down', 5;
    send_key "ret";
    sleep 2;
    send_key "ctrl-f";
    sleep 2;
    type_string "and";
    assert_screen 'gnote-search-body-and', 5;

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
