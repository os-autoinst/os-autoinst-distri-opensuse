# X11 regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Information about current window system
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "x11test";
use strict;
use testapi;

sub run {
    x11_start_program('xterm');
    my $window_system = script_output('echo $XDG_SESSION_TYPE');
    script_run('exit', 0);
    record_info("$window_system", "Current window system is $window_system");
}

1;
