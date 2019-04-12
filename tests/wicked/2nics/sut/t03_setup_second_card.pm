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
use utils 'file_content_replace';
use network_utils 'iface';


sub run {
    my ($self, $ctx) = @_;
    my $config  = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $config2 = '/etc/sysconfig/network/ifcfg-' . $ctx->iface2();
    record_info('Info', 'Set up a second card');
    $self->get_from_data('wicked/static_address/ifcfg-eth0_second_card', $config);
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0',            $config2);
    $self->wicked_command('ifup', $ctx->iface());
    $self->wicked_command('ifup', $ctx->iface2());
    my $iface_ip  = $self->get_ip(type => 'second_card');
    my $iface_ip2 = $self->get_ip(type => 'dhcp');
    validate_script_output('ip a s dev ' . $ctx->iface(),  sub { /$iface_ip/ });
    validate_script_output('ip a s dev ' . $ctx->iface2(), sub { /$iface_ip2/ });
    die "unable to ping " . $ctx->iface()  unless $self->ping_with_timeout(type => 'host',        interface => $ctx->iface());
    die "unable to ping " . $ctx->iface2() unless $self->ping_with_timeout(type => 'second_card', interface => $ctx->iface2());
}

1;
