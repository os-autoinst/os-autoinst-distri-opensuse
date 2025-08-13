# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 12: Create a Bridge interface from Wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $config = '/etc/wicked/ifconfig/bridge.xml';
    record_info('Info', 'Create a Bridge interface from Wicked XML files');
    $self->get_from_data('wicked/xml/bridge.xml', $config);
    $self->setup_bridge($config, '', 'ifup');
    my $res = $self->get_test_result('br0');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
