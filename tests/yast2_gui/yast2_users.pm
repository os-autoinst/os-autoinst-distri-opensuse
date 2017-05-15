# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST2 users GUI
#  Simple launch test
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "y2x11test";
use strict;
use testapi;

sub run() {
    my $self   = shift;
    $self->launch_yast2_module_x11('users', timeout => 60);
    send_key "alt-o";    # OK => Exit
}

1;
# vim: set sw=4 et:
