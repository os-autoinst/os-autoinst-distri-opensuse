# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Controller/master for remote installations
# Tags: poo#9576
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use mm_network;

# poo#9576
sub run {
    my $self = shift;
    assert_screen("remote_slave_ready", 350);
    mutex_create("installation_ready");
    # wait while whole installation process finishes
    $self->wait_boot(bootloader_time => 1800);
}

sub test_flags {
    return {fatal => 1};
}
1;

