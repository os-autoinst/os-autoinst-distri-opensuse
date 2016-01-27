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
use testapi;

sub run() {
    my $self = shift;
    ensure_installed("gnucash");
    ensure_installed("gnucash-docs");

    # needed for viewing
    ensure_installed("yelp");
    x11_start_program("gnucash");
    assert_screen 'test-gnucash-1', 3;
    send_key "ctrl-h";    # open user tutorial
    wait_idle 5;
    assert_screen 'test-gnucash-2', 3;
    send_key "alt-f4";    # Leave tutorial window
                          # Leave tips windows for GNOME case
    if (check_var("DESKTOP", "gnome") || get_var("DESKTOP") eq "xfce") { sleep 3; send_key "alt-c"; }
    wait_idle;
    send_key "ctrl-q";    # Exit

    if (check_screen("gnucash-save-changes", 10)) {
        send_key "alt-w";    # Close _Without Saving
    }
}

1;
# vim: set sw=4 et:
