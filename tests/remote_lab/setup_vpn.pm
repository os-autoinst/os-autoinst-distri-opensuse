# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup VPN to a remote lab using openconnect compatible with Cisco
#  AnyConnect VPN
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use Remote::Lab 'setup_vpn';
use testapi;


sub run {
    my ($self) = @_;
    $self->wait_boot;
    select_console 'tunnel-console';
    setup_vpn();
}

1;
