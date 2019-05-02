# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Teaming, roundrobin
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use utils;
use network_utils 'ifc_exists';
use testapi;


sub run {
    my ($self, $ctx) = @_;

    my $cfg_team0 = '/etc/sysconfig/network/ifcfg-team0';
    my $cfg_ifc0  = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $cfg_ifc1  = '/etc/sysconfig/network/ifcfg-' . $ctx->iface2();

    zypper_call('-q in libteam-tools libteamdctl0 python-libteam');

    $self->get_from_data('wicked/teaming/ifcfg-eth0',             $cfg_ifc0);
    $self->get_from_data('wicked/teaming/ifcfg-eth1',             $cfg_ifc1);
    $self->get_from_data('wicked/teaming/ifcfg-team0-roundrobin', $cfg_team0);
    file_content_replace($cfg_team0, ipaddr4 => $self->get_ip(type => 'host', netmask => 1), ipaddr6 => $self->get_ip(type => 'host6', netmask => 1), port0 => $ctx->iface(), port1 => $ctx->iface2());

    $self->wicked_command('ifup', 'team0');
    die('Missing interface team0') unless ifc_exists('team0');
    validate_script_output('ip a s dev ' . $ctx->iface(),  sub { /master team0/ });
    validate_script_output('ip a s dev ' . $ctx->iface2(), sub { /master team0/ });

    $self->ping_with_timeout(type => 'host', interface => 'team0', count_success => 30, timeout => 4);
}

1;
