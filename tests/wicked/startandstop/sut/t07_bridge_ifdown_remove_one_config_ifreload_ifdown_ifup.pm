# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bridge - ifdown, remove one config, ifreload, ifdown, ifup
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use network_utils 'ifc_exists';

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy  = '/etc/sysconfig/network/ifcfg-dummy0';
    my $res;
    $config = '/etc/sysconfig/network/ifcfg-br0';
    $self->get_from_data('wicked/ifcfg/br0',    $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    $self->wicked_command('ifdown', 'br0');
    $self->wicked_command('ifdown', 'dummy0');
    die if (ifc_exists('dummy0'));
    die if (ifc_exists('br0'));
    assert_script_run("rm $config");
    $self->wicked_command('ifreload', 'all');
    die if (ifc_exists('br0'));
    die unless (ifc_exists('dummy0') && ifc_exists('eth0'));
    $self->wicked_command('ifdown', 'all');
    $self->wicked_command('ifup',   'all');
    die if ($self->get_test_result('host') eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
