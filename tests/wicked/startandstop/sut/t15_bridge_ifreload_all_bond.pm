# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: wicked
# Summary: Bridge - ifreload with bond interfaces
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';

sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/ifreload-3.sh', '/tmp/ifreload-3.sh');
    my $script_cmd = sprintf(q(bond_slaves='%s' time sh /tmp/ifreload-3.sh), join(" ", $ctx->iface, $ctx->iface2));
    $self->run_test_shell_script('ifreload-3', $script_cmd);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
