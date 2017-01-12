# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure USB installation repo is enabled for the case we want to use
#   it to install additional packages.
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: bsc#1012258

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';
    # actually not checking that the first repo is a USB repo but just
    # assuming that the first repo is the install repo should be good enough.
    zypper_call('mr -e 1');
}

1;
# vim: set sw=4 et:
