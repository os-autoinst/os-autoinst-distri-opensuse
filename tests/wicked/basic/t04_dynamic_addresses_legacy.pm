# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Set up dynamic addresses from legacy ifcfg files
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
    record_info('Info', 'Set up dynamic addresses from legacy ifcfg files');
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', "/etc/sysconfig/network/ifcfg-$iface");
    assert_script_run("ifup $iface");
    $self->assert_wicked_state(ping_ip => '10.0.2.2', iface => $iface);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
