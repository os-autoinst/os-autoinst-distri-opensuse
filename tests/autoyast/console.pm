# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Make sure we are logged in
# - Wait for boot if BACKEND is ipmi
# - Set root-console
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use Utils::Backends;

sub run {
    my ($self) = @_;
    # IPXE boot does not provide boot menu so set pxe_boot_done equals 1 without checking needles

    # If we didn't see pxe, the reboot is going now
    $self->wait_boot if is_ipmi && !check_var('IPXE', '1') && !check_var('IPXE_UEFI', '1');

    select_console 'root-console';
}

1;
