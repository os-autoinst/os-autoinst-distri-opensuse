# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Set up a second card
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils 'systemctl';
use lockapi;

sub run {
    my ($self, $ctx) = @_;
    record_info('Info', 'Set up a second card');
    assert_script_run(sprintf("ip a a %s/24 dev %s", $self->get_ip(type => 'dhcp_2nic'),   $ctx->iface()));
    assert_script_run(sprintf("ip a a %s/24 dev %s", $self->get_ip(type => 'second_card'), $ctx->iface()));
    systemctl 'stop dhcpd.service';
    $self->get_from_data('wicked/dhcp/dhcpd_2nics.conf', '/etc/dhcpd.conf');
    $self->sync_start_of('dhcpd', 'dhcpdbasict08');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
