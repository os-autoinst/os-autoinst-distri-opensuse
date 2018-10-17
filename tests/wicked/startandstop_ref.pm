# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startandstop test cases for wicked. Reference machine which used to
#          support tests running on SUT
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;
    my $openvpn_server = '/etc/openvpn/server.conf';

    record_info('Test 1', 'Bridge - ifreload');
    mutex_wait('test_1_ready');

    record_info('Test 2', 'Bridge - ifup, ifreload');
    mutex_wait('test_2_ready');

    record_info('Test 3', 'Bridge - ifup, remove all config, ifreload');
    mutex_wait('test_3_ready');

    record_info('Test 4', 'Bridge - ifup, remove one config, ifreload');
    mutex_wait('test_4_ready');

    record_info('Test 5', 'Standalone card - ifdown, ifreload');
    mutex_wait('test_5_ready');

    record_info('Test 8', 'Bridge - ifdown, remove one config, ifreload, ifdown, ifup');
    mutex_wait('test_8_ready');

    record_info('Test 21', 'SIT tunnel - ifdown');
    $self->create_tunnel_with_commands('sit1', 'sit', '127');
    mutex_wait('test_21_ready');
    assert_script_run('ip addr flush dev sit1');
    assert_script_run('ip tunnel delete sit1');

    record_info('Test 22', 'OpenVPN tunnel - ifdown');
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    $self->get_from_data('wicked/ifcfg/tun1_ref',      $config);
    $self->get_from_data('wicked/openvpn/server.conf', $openvpn_server);
    assert_script_run("sed \'s/device/tun1/\' -i $openvpn_server");
    $self->setup_tuntap($config, "tun1", 1);
    mutex_wait('test_22_ready');
    $self->cleanup($config, "tun1");
}

1;
