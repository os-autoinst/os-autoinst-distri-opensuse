# SUSE's openQA tests
#
# Copyright 2019-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked-service wicked
# Summary: Hotplug deconnection and reconnection
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils 'systemctl';


sub run {
    my ($self, $ctx) = @_;
    systemctl('is-enabled wickedd-nanny.service');
    $self->get_from_data('wicked/ifbind.sh', 'ifbind.sh', executable => 1);
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifup', $ctx->iface());
    $self->ping_with_timeout(type => 'host', interface => $ctx->iface());
    assert_script_run('./ifbind.sh unbind ' . $ctx->iface());
    assert_script_run('./ifbind.sh bind ' . $ctx->iface());
    $self->ping_with_timeout(type => 'host', interface => $ctx->iface());
}

sub test_flags {
    return {always_rollback => 1};
}

1;
