# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
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
use testapi;
use registration 'add_suseconnect_product';
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->wait_boot;
    select_console 'root-console';
    add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1) if is_sle;
    zypper_call 'in --no-recommends openconnect';
    script_run 'read -s vpn_password', 0;
    type_password get_required_var('_SECRET_VPN_PASSWORD') . "\n";
}

1;
