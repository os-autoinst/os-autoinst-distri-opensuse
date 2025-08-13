# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Set up dynamic addresses from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use base 'wickedbase';
use testapi;
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    my $config = '/data/dynamic_address/dynamic-addresses.xml';
    sleep 30;    # W/A give ovs some time for setup !?
    record_info('Info', 'Set up dynamic addresses from wicked XML files');
    $self->get_from_data('wicked/dynamic_address/dynamic-addresses.xml', $config);
    file_content_replace($config, '--sed-modifier' => 'g', xxx => $ctx->iface());
    $self->wicked_command('ifup --ifconfig /data/dynamic_address/dynamic-addresses.xml', $ctx->iface());
    $self->assert_wicked_state(ping_ip => $self->get_remote_ip(type => 'host'), iface => $ctx->iface());
}

sub test_flags {
    return {always_rollback => 1};
}

1;
