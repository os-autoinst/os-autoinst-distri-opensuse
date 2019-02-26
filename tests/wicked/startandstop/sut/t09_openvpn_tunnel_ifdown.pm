# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: OpenVPN tunnel - ifdown
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use network_utils 'ifc_exists';

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg/tun1_sut', $config);
    $self->setup_openvpn_client('tun1');
    $self->setup_tuntap($config, 'tun1');
    die if ($self->get_test_result('tun1') eq 'FAILED');
    $self->wicked_command('ifdown', 'tun1');
    die if (ifc_exists('tun1'));
    die if (script_run('systemctl -q is-active openvpn@client') == 0);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
