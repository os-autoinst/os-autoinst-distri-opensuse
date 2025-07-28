# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked iproute2
# Summary: VLAN - Create a VLAN from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use base 'wickedbase';
use testapi;
use network_utils 'ifc_exists';
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    my $config = '/etc/wicked/ifconfig/vlan.xml';
    $self->get_from_data('wicked/xml/vlan.xml', $config);
    file_content_replace($config, iface => $ctx->iface(), ip_address => $self->get_ip(type => 'vlan', netmask => 1));
    record_info('Info', 'VLAN - Create a VLAN from wicked XML files');
    $self->wicked_command('ifreload', 'all');
    assert_script_run('ip a');
    die('VLAN interface does not exists') unless ifc_exists($ctx->iface() . '.42');
    $self->ping_with_timeout(type => 'vlan', timeout => '50');
}

1;
