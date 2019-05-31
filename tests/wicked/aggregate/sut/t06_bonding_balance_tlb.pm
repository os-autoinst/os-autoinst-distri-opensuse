# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bonding, Balance-tlb
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;


sub run {
    my ($self, $ctx) = @_;
    record_info('INFO', 'Bonding, Balance-tlb');
    $self->setup_bond('tlb', $ctx->iface(), $ctx->iface2());
    $self->validate_interfaces('bond0', $ctx->iface(), $ctx->iface2());
}

sub test_flags {
    return {always_rollback => 1};
}

1;
