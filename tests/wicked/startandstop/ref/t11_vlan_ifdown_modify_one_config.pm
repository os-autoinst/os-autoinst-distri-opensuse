# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: VLAN - ifdown, modify one config, ifreload, ifdown, ifup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use network_utils 'iface';

sub run {
    my ($self) = @_;
    my $iface = iface();
    my $local_ip = $self->get_ip(type => 'vlan_changed', netmask => 1);
    record_info('Info', 'VLAN - ifdown, modify one config, ifreload, ifdown, ifup');
    assert_script_run("ip link add link $iface name $iface.42 type vlan id 42");
    assert_script_run('ip link');
    assert_script_run("ip -d link show $iface.42");
    assert_script_run("ip addr add $local_ip dev $iface.42");
    assert_script_run("ip link set dev $iface.42 up");
}

1;
