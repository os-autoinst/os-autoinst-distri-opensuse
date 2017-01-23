# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;


sub run() {
    assert_script_run
      "zypper -n --no-gpg-checks in --auto-agree-with-licenses -t pattern SLEPOS_Server_Admin > /dev/$serialdev";
}

sub test_flags() {
    return {fatal => 1};
}


1;
# vim: set sw=4 et:
