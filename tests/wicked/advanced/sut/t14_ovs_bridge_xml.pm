# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 14: Create OVS Bridge interface from Wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $config = '/etc/wicked/ifconfig/ovs-bridge.xml';
    record_info('Info', 'Create a Bridge interface from Wicked XML files');
    $self->get_from_data('wicked/xml/ovs-bridge.xml', $config);
    assert_script_run('ifdown ' . $ctx->iface());
    assert_script_run('rm /etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->setup_bridge($config, '', 'ifup');
    record_info('INFO', script_output('ovs-vsctl show'));
    my $res = $self->get_test_result('br0');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
