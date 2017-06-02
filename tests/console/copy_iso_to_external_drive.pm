# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Copy the installation ISO to an external drive
#    test for bug boo#1040749
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

use base "x11test";
use strict;
use testapi;

sub run() {
    select_console 'user-console';
    # select_console 'root-console';

    script_run "mount | tee /dev/$serialdev";
    # TODO
}

1;
# vim: set sw=4 et:
