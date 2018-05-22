# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the desktop runner which is a prerequisite for many other
#   modules
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run {
    # we do not want to validate the result but leave this for other modules
    x11_start_program('true', valid => 0, no_wait => 1);
}

1;
