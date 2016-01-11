# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2x11test";
use testapi;

sub run() {
    my $self   = shift;
    my $module = "host";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 30;
    send_key "alt-o";    # OK => Exit
}

1;
# vim: set sw=4 et:
