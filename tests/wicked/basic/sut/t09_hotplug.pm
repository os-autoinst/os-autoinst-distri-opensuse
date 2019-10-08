# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

1;
