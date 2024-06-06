# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFA
# Maintainer: qe-core <qe-core@suse.de>, qe-sap <qe-sap@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use utils qw(fully_patch_system);
use power_action_utils qw(prepare_system_shutdown power_action);

sub run{
    my $self = @_;
    select_serial_terminal();
    record_info("Prepatch", "Bringig the image to a released state.");
    fully_patch_system;
    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot(bootloader_time => 200);
    record_info("Done", "SUT up to date");
}

1;
