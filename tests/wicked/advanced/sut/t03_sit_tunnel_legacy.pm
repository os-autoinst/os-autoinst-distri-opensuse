# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 3 : Create a SIT interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-sit1';
    record_info('Info', 'Create a SIT interface from legacy ifcfg files');
    $self->get_from_data('wicked/static_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->get_from_data('wicked/ifcfg/sit1', $config);
    $self->setup_tunnel($config, 'sit1', $ctx->iface());
    my $res = $self->get_test_result('sit1', 'v6');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
