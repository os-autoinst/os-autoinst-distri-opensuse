# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
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
use network_utils qw(iface ifc_exists);
use utils 'file_content_replace';

sub run {
    my ($self) = @_;
    my $iface  = iface();
    my $config = "/etc/sysconfig/network/ifcfg-$iface.42";
    $self->get_from_data('wicked/ifcfg/eth0.42', $config);
    my $local_ip = $self->get_ip(type => 'vlan', netmask => 1);
    $local_ip =~ s'/'\\/';
    file_content_replace($config, interface => $iface, ip_address => $local_ip);
    $self->wicked_command('ifup', 'all');
    assert_script_run('ip a');
    die if (!ifc_exists($iface . '.42'));
    $self->wicked_command('ifdown', "$iface.42");
    die if (ifc_exists($iface . '.42'));
    die if (!ifc_exists($iface));
}


1;
