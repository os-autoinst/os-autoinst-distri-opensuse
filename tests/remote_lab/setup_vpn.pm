# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup VPN to a remote lab using openconnect compatible with Cisco
#  AnyConnect VPN
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use strict;
use warnings;
use Remote::Lab 'setup_vpn';
use testapi;


sub run {
    my ($self) = @_;
    $self->wait_boot;
    select_console 'tunnel-console';
    setup_vpn();
}

1;
