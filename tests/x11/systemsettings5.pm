# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Separate systemsettings test for KDE4-based and KF5-based
#    In update test, there might have old KDE4 systemsettings as another
#    candidate in krunner via auto-completion, therefore, separate
#    systemsettings test to systemsettings(KDE4-based) and
#    systemsettings5(KF5-based) test.
#
#    openSUSE version less than or equal to 13.2 have to set KDE4 variable as
#    1, thus PLASMA5 variable won't be sets.
# G-Maintainer: Max Lin <mlin@suse.com>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("systemsettings5", 6, {valid => 1});
    assert_screen 'test-systemsettings-1';
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
