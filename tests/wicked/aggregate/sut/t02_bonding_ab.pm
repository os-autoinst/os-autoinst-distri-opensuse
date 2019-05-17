# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bonding, active-backup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils 'file_content_replace';


sub run {
    my ($self, $ctx) = @_;
    my $sut_iface = 'bond0';
    my $config    = '/etc/sysconfig/network/ifcfg-' . $sut_iface;
    my $cfg_ifc0  = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $cfg_ifc1  = '/etc/sysconfig/network/ifcfg-' . $ctx->iface2();
    record_info('Info', 'Bonding, active-backup');
    $self->get_from_data('wicked/ifcfg/bond0-ab',     $config);
    $self->get_from_data('wicked/ifcfg/noip_hotplug', $cfg_ifc0);
    $self->get_from_data('wicked/ifcfg/noip_hotplug', $cfg_ifc1);
    file_content_replace($config, iface0 => $ctx->iface(), iface1 => $ctx->iface2(), ip_address => $self->get_ip(type => 'bond'), sed_modifier => 'g', ipaddr6 => $self->get_ip(type => 'host6', netmask => 1));
    $self->wicked_command('ifup', $sut_iface);
    validate_script_output('ip a s dev ' . $ctx->iface(),  sub { /SLAVE/ });
    validate_script_output('ip a s dev ' . $ctx->iface2(), sub { /SLAVE/ });
    $self->ping_with_timeout(interface => $sut_iface, type => 'host', count_success => 30, timeout => 4);
}

1;
