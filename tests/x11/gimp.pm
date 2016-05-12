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

# XXX TODO - is using KDE variable here
sub run() {
    my $self = shift;
    ensure_installed("gimp");
    x11_start_program("gimp");
    assert_screen "test-gimp-1", 20;
    send_key "alt-f4";    # Exit
}

1;
# vim: set sw=4 et:
