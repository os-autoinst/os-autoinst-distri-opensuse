# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: OpenVPN tunnel - ifdown
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;
use network_utils 'ifc_exists';

sub run {
    my ($self, $ctx) = @_;
    my $iface = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/static_address/ifcfg-eth0', $iface);
    $self->get_from_data('wicked/ifcfg/tun1_sut', $config);
    $self->setup_openvpn_client('tun1');
    $self->setup_tuntap($config, 'tun1');
    die if ($self->get_test_result('tun1') eq 'FAILED');
    $self->wicked_command('ifdown', 'tun1');
    die if (ifc_exists('tun1'));
    die if (script_run('systemctl -q is-active openvpn@client') == 0);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
