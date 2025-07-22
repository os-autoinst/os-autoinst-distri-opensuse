# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Bridge - ifup, remove all config, ifreload
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
    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug', $iface);
    $self->get_from_data('wicked/ifcfg/br0', $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    assert_script_run("rm $iface $config $dummy");
    $self->wicked_command('ifreload', 'all');
    die if (ifc_exists('dummy0') || ifc_exists('br0'));
}

sub test_flags {
    return {always_rollback => 1};
}

1;
