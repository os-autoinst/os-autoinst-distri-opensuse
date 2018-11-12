# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 7 : Create a tun interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-tun1';
    record_info('Info', 'Create a tun interface from legacy ifcfg files');
    $self->get_from_data('wicked/ifcfg/tun1_sut', $config);
    $self->setup_openvpn_client('tun1');
    $self->setup_tuntap($config, 'tun1');
    my $res = $self->get_test_result('tun1');
    die if ($res eq 'FAILED');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
