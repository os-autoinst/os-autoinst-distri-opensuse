# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: VLAN - ifup all, ifdown one card
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use network_utils 'ifc_exists';
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-' . $ctx->iface() . '.42';
    $self->get_from_data('wicked/ifcfg/eth0.42', $config);
    file_content_replace($config, interface => $ctx->iface(), ip_address => $self->get_ip(type => 'vlan', netmask => 1));
    $self->wicked_command('ifup', 'all');
    die if (!ifc_exists($ctx->iface() . '.42'));
    $self->wicked_command('ifdown', $ctx->iface() . '.42');
    die if (ifc_exists($ctx->iface() . '.42'));
    die if (!ifc_exists($ctx->iface()));
}

sub test_flags {
    return {always_rollback => 1};
}

1;
