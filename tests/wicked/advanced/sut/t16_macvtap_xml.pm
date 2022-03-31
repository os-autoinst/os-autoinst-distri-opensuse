# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 16: Create a macvtap interface from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;


sub run {
    my ($self, $ctx) = @_;
    record_info('Info', 'Create a macvtap interface from wicked XML files');
    my $config = '/etc/wicked/ifconfig/macvtap.xml';
    $self->get_from_data('wicked/xml/macvtap.xml', $config);
    $self->prepare_check_macvtap($config, $ctx->iface(), $self->get_ip(type => 'macvtap', netmask => 1), $self->unique_macaddr());
    $self->wicked_command('ifreload', $ctx->iface());
    $self->wicked_command('ifup', 'macvtap1');
    $self->validate_macvtap();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
