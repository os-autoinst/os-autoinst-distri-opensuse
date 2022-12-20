# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Hotplug constituents of aggregated links
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;
use utils 'systemctl';


sub run {
    my ($self, $ctx) = @_;
    systemctl('is-enabled wickedd-nanny.service');
    $self->get_from_data('wicked/ifbind.sh', 'ifbind.sh', executable => 1);
    record_info('INFO', 'Hotplug constituents of aggregated links');
    $self->setup_bond('rr', $ctx->iface(), $ctx->iface2());
    $self->validate_interfaces('bond0', $ctx->iface(), $ctx->iface2());
    assert_script_run('./ifbind.sh unbind ' . $ctx->iface());
    $self->validate_interfaces('bond0', undef, $ctx->iface2());
    assert_script_run('./ifbind.sh bind ' . $ctx->iface());
    sleep 30;
    $self->validate_interfaces('bond0', $ctx->iface(), $ctx->iface2());
}

1;
