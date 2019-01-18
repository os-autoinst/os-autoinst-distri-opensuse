# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test YaST2 module for software management
# Maintainer: Max Lin <mlin@suse.com>

use base "y2x11test";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    select_console 'x11';
    $self->launch_yast2_module_x11('sw_single', match_timeout => 120);
    send_key "alt-a";    # Accept => Exit
}

1;
