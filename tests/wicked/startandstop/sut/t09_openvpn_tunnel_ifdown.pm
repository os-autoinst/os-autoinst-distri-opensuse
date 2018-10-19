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
use testapi;
use lockapi;

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg/tun1_sut', $config);
    $self->setup_openvpn_client('tun1');
    $self->setup_tuntap($config, 'tun1', 0);
    my $res = $self->get_test_result('tun1');
    if ($res ne 'FAILED') {
        assert_script_run('wicked ifdown --timeout infinite tun1');
        my $res1 = script_run('ip link | grep tun1');
        my $res2 = script_run('systemctl -q is-active openvpn@client');
        if (!$res1 || !$res2) {
            $res = 'FAILED';
        }
    }
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1, wicked_need_sync => 1};
}

1;
