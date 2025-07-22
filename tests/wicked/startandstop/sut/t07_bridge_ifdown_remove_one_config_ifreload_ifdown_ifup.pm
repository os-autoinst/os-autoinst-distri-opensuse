# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Bridge - ifdown, remove one config, ifreload, ifdown, ifup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;
use network_utils 'ifc_exists';

sub run {
    my ($self, $ctx) = @_;
    my $iface = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy = '/etc/sysconfig/network/ifcfg-dummy0';
    my $res;
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', $iface);
    $self->get_from_data('wicked/ifcfg/br0', $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    $self->wicked_command('ifdown', 'br0');
    $self->wicked_command('ifdown', 'dummy0');
    die if (ifc_exists('dummy0'));
    die if (ifc_exists('br0'));
    assert_script_run("rm $config");
    $self->wicked_command('ifreload', 'all');
    die if (ifc_exists('br0'));
    die unless (ifc_exists('dummy0') && ifc_exists($ctx->iface()));
    $self->wicked_command('ifdown', 'all');
    $self->wicked_command('ifup', 'all');
    die if ($self->get_test_result('host') eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
