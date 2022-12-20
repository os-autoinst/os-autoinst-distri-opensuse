# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Bridge - ifdown, create new config, ifreload, ifdown, ifup
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
    my $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy = '/etc/sysconfig/network/ifcfg-dummy0';
    $self->get_from_data('wicked/ifcfg/br0', $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    $self->wicked_command('ifdown', 'br0');
    $self->wicked_command('ifdown', 'dummy0');
    die if (ifc_exists('dummy0') || ifc_exists('br0'));
    $self->wicked_command('ifreload', 'all');
    die unless (ifc_exists('br0') && ifc_exists('dummy0'));
    my $current_ip = $self->get_current_ip('br0');
    my $expected_ip = $self->get_ip(type => 'br0');
    die('IP mismatch', 'IP is ' . ($current_ip || 'none') . ' but expected was ' . $expected_ip)
      if (!defined($current_ip) || $current_ip ne $expected_ip);
    die if ($self->get_test_result('br0') eq 'FAILED');
    $self->wicked_command('ifdown', 'all');
    $self->wicked_command('ifup', 'all');
    die if ($self->get_test_result('br0') eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
