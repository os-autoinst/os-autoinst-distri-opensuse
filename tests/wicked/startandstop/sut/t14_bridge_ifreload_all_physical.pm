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
use testapi;


sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/scripts/ifreload-2.sh', '/tmp/ifreload-2.sh');
    my $script_cmd = sprintf(q(time dev=%s sh /tmp/ifreload-2.sh -d), $ctx->iface);
    $self->run_test_shell_script('ifreload-2', $script_cmd);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
