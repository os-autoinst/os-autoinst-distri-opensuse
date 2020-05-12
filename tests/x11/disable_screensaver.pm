# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Disable screensaver depending on desktop environment
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use x11utils 'turn_off_screensaver';

sub run {
    select_console 'x11';
    turn_off_screensaver;
}

1;
