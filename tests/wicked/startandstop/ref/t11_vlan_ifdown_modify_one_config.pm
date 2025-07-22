# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iproute2
# Summary: VLAN - ifdown, modify one config, ifreload, ifdown, ifup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;
use network_utils 'iface';

sub run {
    my ($self) = @_;
    record_info('Info', 'VLAN - ifdown, modify one config, ifreload, ifdown, ifup');
    $self->setup_vlan('vlan_changed');
}

sub test_flags {
    return {always_rollback => 1};
}
1;
