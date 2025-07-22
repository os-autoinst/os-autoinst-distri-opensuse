# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Set up dynamic addresses from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    record_info('Info', 'Set up dynamic addresses from legacy ifcfg files');
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifup', $ctx->iface());
    $self->assert_wicked_state(ping_ip => $self->get_remote_ip(type => 'host'), iface => $ctx->iface());
}

sub test_flags {
    return {always_rollback => 1};
}

1;
