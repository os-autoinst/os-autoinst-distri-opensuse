# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bonding, active-backup, miimon
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;


sub run {
    my ($self, $ctx) = @_;
    my $failover_timeout = get_var('FAILOVER_TIMEOUT', 60);
    record_info('INFO', 'Bonding, active-backup, miimon');
    $self->setup_bond('ab', $ctx->iface(), $ctx->iface2());
    $self->validate_interfaces('bond0', $ctx->iface(), $ctx->iface2());
    my $active_link = $self->get_bond_active_link('bond0');
    $self->ifbind('unbind', $active_link);
    while ($failover_timeout >= 0) {
        last if ($self->get_bond_active_link('bond0') ne $active_link);
        $failover_timeout -= 1;
        sleep 1;
    }
    die('Active Link is the same after interface cut') if ($failover_timeout == 0);
    $self->ping_with_timeout(type => 'host', interface => 'bond0', count_success => 30, timeout => 4);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
