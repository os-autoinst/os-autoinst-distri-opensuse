# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use strict;
use testapi;

sub run() {
    assert_screen "qa-net-selection", 300;
    # boot to hard disk is default
    send_key 'ret';

}

sub test_flags() {
    return {fatal => 1};
}


1;

# vim: set sw=4 et:
