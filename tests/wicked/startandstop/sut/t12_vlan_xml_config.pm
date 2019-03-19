# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: VLAN - Create a VLAN from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use base 'wickedbase';
use strict;
use warnings;
use testapi;
use network_utils qw(iface ifc_exists);
use utils 'file_content_replace';

sub run {
    my ($self) = @_;
    my $iface  = iface();
    my $config = '/etc/wicked/ifconfig/vlan.xml';
    $self->get_from_data('wicked/xml/vlan.xml', $config);
    my $local_ip = $self->get_ip(type => 'vlan', netmask => 1);
    $local_ip =~ s'/'\\/';
    file_content_replace($config, iface => $iface, ip_address => $local_ip);
    record_info('Info', 'VLAN - Create a VLAN from wicked XML files');
    $self->wicked_command('ifreload', 'all');
    assert_script_run('ip a');
    die('VLAN interface does not exists') unless ifc_exists($iface . '.42');
    die('IP is unreachable')
      unless $self->ping_with_timeout(type => 'vlan', timeout => '50');
}

1;
