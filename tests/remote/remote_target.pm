# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller/master for remote installations
# Tags: poo#9576
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "y2_installbase";
use testapi;
use lockapi;
use mm_network;


# poo#9576
sub run {
    my $self = shift;
    assert_screen("remote_slave_ready", 350);
    mutex_create("installation_ready");
    # wait while whole installation process finishes
    mutex_wait("installation_done");
    $self->wait_boot(bootloader_time => 120);
}

1;
