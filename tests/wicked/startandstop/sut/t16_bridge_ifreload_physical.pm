# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Bridge - ifreload with bond interfaces
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';

sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/ifreload-4.sh', '/tmp/ifreload-4.sh');
    my $script_cmd = sprintf(q(time bridge_port='%s' sh /tmp/ifreload-4.sh), $ctx->iface2);
    $self->run_test_shell_script('ifreload-4', $script_cmd);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
