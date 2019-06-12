# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Teaming, Active-Backup All Link
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;


sub run {
    my ($self, $ctx) = @_;
    record_info('INFO', 'Teaming, Active-Backup All Link');
    $self->setup_team('ab-all', $ctx->iface(), $ctx->iface2());
    $self->validate_interfaces('team0', $ctx->iface(), $ctx->iface2(), 0);
    $self->check_fail_over('team0');
    $self->ping_with_timeout(type => 'host', interface => 'team0', count_success => 30, timeout => 4);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
