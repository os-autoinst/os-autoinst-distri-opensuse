# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 13: Create OVS Bridge interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy  = '/etc/sysconfig/network/ifcfg-dummy0';
    record_info('Info', 'Create OVS Bridge interface from legacy ifcfg files');
    $self->get_from_data('wicked/ifcfg/ovsbr0', $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifup');
    record_info('INFO', script_output('ovs-vsctl show'));
    my $res = $self->get_test_result('br0');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
