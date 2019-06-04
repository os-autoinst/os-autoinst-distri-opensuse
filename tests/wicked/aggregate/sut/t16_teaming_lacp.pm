# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Teaming, LACP
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;
use network_utils 'ifc_is_up';

sub run {
    my ($self, $ctx) = @_;
    record_info('INFO', 'Teaming, LACP');
    $self->setup_team('lacp', $ctx->iface(), $ctx->iface2());
    validate_script_output('ip a s dev ' . $ctx->iface(),  sub { /master team0/ });
    validate_script_output('ip a s dev ' . $ctx->iface2(), sub { /master team0/ });
    if (!ifc_is_up('team0')) {
        record_info('INFO',            "Team interface 'team0' is not UP");
        record_info('wicked ifstatus', script_output("wicked ifstatus --verbose all"));
        record_info('teamdctl',        script_output("teamdctl team0 state view"));
    }
    else {
        die("Team interface is magically UP! This shouldn't happen in this environment...");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
