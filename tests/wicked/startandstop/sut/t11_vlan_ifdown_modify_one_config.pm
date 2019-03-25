# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: VLAN - ifup all, ifdown one card
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use network_utils 'ifc_exists';
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    my $config   = '/etc/sysconfig/network/ifcfg-' . $ctx->iface() . '.42';
    my $local_ip = $self->get_ip(type => 'vlan_changed', netmask => 1);
    $local_ip =~ s'/'\\/';
    my $previous_ip = $self->get_ip(type => 'vlan', netmask => 1);
    $previous_ip =~ s'/'\\/';
    file_content_replace($config, $previous_ip => $local_ip);
    $self->wicked_command('ifreload', 'all');
    assert_script_run('ip a');
    die('VLAN interface does not exists') unless ifc_exists($ctx->iface() . '.42');
    die('IP is unreachable')
      unless $self->ping_with_timeout(type => 'vlan_changed', timeout => '50');
    $self->wicked_command('ifdown', "all");
    die('VLAN interface exists') if (ifc_exists($ctx->iface() . '.42'));
}

sub test_flags {
    return {always_rollback => 1};
}

1;
