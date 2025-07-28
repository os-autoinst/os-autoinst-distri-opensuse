# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked iproute2
# Summary: Create a team interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;
use network_utils 'ifc_exists';
use utils 'file_content_replace';


sub run {
    my ($self, $ctx) = @_;

    record_info('Info', 'Create a team interface from legacy ifcfg files');
    $self->setup_team('activebackup', $ctx->iface(), $ctx->iface2());
    $self->validate_interfaces('team0', $ctx->iface(), $ctx->iface2());

}

sub test_flags {
    return {always_rollback => 1};
}

1;
