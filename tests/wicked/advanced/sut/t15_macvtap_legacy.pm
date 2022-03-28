# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 15: Create a macvtap interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self, $ctx) = @_;
    record_info('Info', 'Create a macvtap interface from legacy ifcfg files');
    my $config = '/etc/sysconfig/network/ifcfg-macvtap1';
    $self->get_from_data('wicked/ifcfg/macvtap1', $config);
    $self->get_from_data('wicked/ifcfg/macvtap_eth', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->prepare_check_macvtap($config, $ctx->iface(), $self->get_ip(type => 'macvtap', netmask => 1), $self->unique_macaddr());
    $self->wicked_command('ifreload', $ctx->iface());
    $self->wicked_command('ifup', 'macvtap1');
    $self->validate_macvtap();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
