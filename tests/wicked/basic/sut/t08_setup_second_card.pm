# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Set up a second card
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use lockapi;

sub run {
    my ($self, $ctx) = @_;
    my $cfg_ifc1 = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $cfg_ifc2 = '/etc/sysconfig/network/ifcfg-' . $ctx->iface2();
    record_info('Info', 'Set up a second card');
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', $cfg_ifc1);
    $self->get_from_data('wicked/static_address/ifcfg-eth0',  $cfg_ifc2);
    $self->wicked_command('ifdown', 'all');
    mutex_wait('t08_dhcpd_setup_complete');
    $self->wicked_command('ifup', $ctx->iface());
    $self->wicked_command('ifup', $ctx->iface2());
    my $iface_ip  = $self->get_ip(type => 'dhcp_2nic');
    my $iface_ip2 = $self->get_ip(type => 'host');
    validate_script_output('ip a s dev ' . $ctx->iface(),  sub { /$iface_ip/ });
    validate_script_output('ip a s dev ' . $ctx->iface2(), sub { /$iface_ip2/ });
    $self->ping_with_timeout(type => 'second_card', interface => $ctx->iface());
    $self->ping_with_timeout(type => 'host',        interface => $ctx->iface2());
    my $static_gw = '10.0.2.2';
    if (script_output('ip r s | grep default | awk \'{print $3}\'') ne $static_gw) {
        record_soft_failure("Default gw not $static_gw");
    } else {
        validate_script_output('tracepath -n -m 5 8.8.8.8', sub { index($_, $static_gw) != -1 });
    }
}

1;
