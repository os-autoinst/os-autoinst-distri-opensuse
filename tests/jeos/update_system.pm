# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module is to be used by maintenance updates jobs where
#   we use the GM images to test aggregates. We need to update the system
#   before adding the maintenance updates to be tested.
#
# Maintainer: qa-c team <qa-c@suse.de>>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call ensure_ca_certificates_suse_installed);
use power_action_utils qw(power_action);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    ensure_ca_certificates_suse_installed;

    zypper_call('ar -f ' . get_required_var('UPDATE_REPO'));
    zypper_call('up');
    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => get_var('BOOTLOADER_TIMEOUT', 150));

}

sub test_flags {
    return {fatal => 1};
}

1;
