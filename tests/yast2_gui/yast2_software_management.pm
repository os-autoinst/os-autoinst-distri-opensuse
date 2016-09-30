# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add YaST2 UI tests
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# G-Maintainer: Max Lin <mlin@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run() {
    my $self   = shift;
    my $module = "sw_single";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 120;
    send_key "alt-a";    # Accept => Exit
}

1;
# vim: set sw=4 et:
