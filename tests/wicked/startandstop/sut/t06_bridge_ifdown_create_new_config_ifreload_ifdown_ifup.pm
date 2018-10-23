# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bridge - ifdown, create new config, ifreload, ifdown, ifup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy  = '/etc/sysconfig/network/ifcfg-dummy0';
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    assert_script_run('wicked ifdown --timeout infinite br0');
    assert_script_run('wicked ifdown --timeout infinite dummy0');
    die if (script_run(q(ip link | grep 'dummy0\|br0')) == 0);
    assert_script_run('wicked ifreload --timeout infinite all');
    my $res1 = script_run('ip link | grep br0');
    my $res2 = script_run('ip link | grep dummy0');
    die if ($res1 || $res2);
    my $current_ip = $self->get_current_ip('br0');
    my $expected_ip = $self->get_ip(type => 'br0', no_mask => 1);
    if (!defined($current_ip) || $current_ip ne $expected_ip) {
        record_info('IP missmatch', 'IP is ' . ($current_ip || 'none')
              . ' but expected was ' . $expected_ip, result => 'fail');
        die;
    }
    die if ($self->get_test_result('br0') eq 'FAILED');
    assert_script_run('wicked ifdown --timeout infinite all');
    assert_script_run('wicked ifup --timeout infinite all');
    die if ($self->get_test_result('br0') eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1, wicked_need_sync => 1};
}

1;
