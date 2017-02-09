# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Adminserver configured mutex
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use warnings;
use base "basetest";
use testapi;
use utils;
use lockapi;

sub run() {
    my $self = shift;

    mutex_create("adminserver_configured");

}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
