# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Standalone card - ifdown, ifreload
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use network_utils 'iface';

sub run {
    my ($self) = @_;
    my $iface  = iface();
    my $config = '/etc/sysconfig/network/ifcfg-' . $iface;
    my $res;
    record_info('Info', 'Standalone card - ifdown, ifreload');
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', $config);
    $self->wicked_command('ifdown',   $iface);
    $self->wicked_command('ifreload', $iface);
    my $static_ip = $self->get_ip(type => 'host');
    my $dhcp_ip = $self->get_current_ip($iface);
    if (defined($dhcp_ip) && $static_ip ne $dhcp_ip) {
        $res = $self->get_test_result('host');
    } else {
        record_info('DHCP failed', 'current ip: ' . ($dhcp_ip || 'none'), result => 'fail');
        $res = 'FAILED';
    }
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
