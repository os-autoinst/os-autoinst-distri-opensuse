# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Basic SLEPOS test
# G-Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use testapi;
use utils;


sub run() {
    my $self = shift;

    assert_script_run "zypper -n --no-gpg-checks in --auto-agree-with-licenses -t pattern SLEPOS_Image_Server > /dev/$serialdev";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
