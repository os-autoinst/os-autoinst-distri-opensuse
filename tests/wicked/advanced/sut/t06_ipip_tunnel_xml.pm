# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 6 : Create a IPIP interface from Wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $config = '/etc/wicked/ifconfig/ipip.xml';
    record_info('Info', 'Create a IPIP interface from Wicked XML files');
    $self->get_from_data('wicked/xml/ipip.xml', $config);
    $self->setup_tunnel($config, 'tunl1', $ctx->iface());
    my $res = $self->get_test_result('tunl1');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
